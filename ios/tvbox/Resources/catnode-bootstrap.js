// Cat 配置包宿主脚本，由 CatNodeRuntime 通过 nodejs-mobile 启动。
// 用法: node catnode-bootstrap.js <dataDir>
//
// 1. 在 127.0.0.1 随机端口启动控制服务，端口写入 <dataDir>/control.port。
// 2. POST /run {"path": "<目录>"}：停止旧配置包，require <目录>/index.js 并以
//    <目录>/index.config.js 为配置调用 start()，等配置包的 HTTP 服务开始监听后返回 {"port": n}。
// 3. GET /status：返回当前配置包服务端口，未运行时为 0。
const http = require('http');
const fs = require('fs');
const path = require('path');
const { builtinModules } = require('module');

// 配置包按 Cat 宿主约定直接使用全局的 Node 内置模块。
// 先加载公开模块再加载 _tls_wrap 等内部模块：内部模块先加载会让循环依赖的
// tls 导出不完整（tls.createSecureContext 为 undefined），所有 HTTPS 请求失败。
[...builtinModules].sort((a, b) => a.startsWith('_') - b.startsWith('_')).forEach(mod => {
  if (mod !== 'trace_events') {
    try {
      globalThis[mod] = require(mod);
    } catch (e) {
      // 部分内置模块在 nodejs-mobile 上不可用，忽略即可。
    }
  }
});

const dataDir = process.argv[2] || process.cwd();
// 配置包把网盘 Cookie/Token 等数据写到 $NODE_PATH/db.json。
process.env.NODE_PATH = dataDir;
process.chdir(dataDir);

let sourceModule = null;
let serverPort = 0;
let listeningWaiters = [];

// 宿主没有原生消息服务，返回 0 让配置包只使用本地 db.json。
globalThis.catDartServerPort = () => 0;

globalThis.catServerFactory = handle => {
  const server = http.createServer((req, res) => handle(req, res));
  server.on('listening', () => {
    serverPort = server.address().port;
    console.log('Cat bundle listening on ' + serverPort);
    listeningWaiters.splice(0).forEach(resolve => resolve(serverPort));
  });
  return server;
};

async function runBundle(dir) {
  try {
    await sourceModule?.stop?.();
  } catch (e) {
    console.warn('stop error', e);
  }
  sourceModule = null;
  serverPort = 0;

  const listening = new Promise((resolve, reject) => {
    listeningWaiters.push(resolve);
    setTimeout(() => reject(new Error('配置包服务启动超时')), 30000);
  });

  const indexPath = path.join(dir, 'index.js');
  const configPath = path.join(dir, 'index.config.js');
  delete require.cache[require.resolve(indexPath)];
  delete require.cache[require.resolve(configPath)];
  sourceModule = require(indexPath);
  const config = require(configPath);
  // start() 在开始监听后还会继续做初始化，不等待它结束。
  Promise.resolve(sourceModule.start(config.default || config)).catch(e => {
    console.error('start error', e);
  });
  return listening;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.setEncoding('utf8');
    req.on('data', chunk => (body += chunk));
    req.on('end', () => resolve(body));
    req.on('error', reject);
  });
}

const control = http.createServer(async (req, res) => {
  const send = (code, obj) => {
    res.writeHead(code, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(obj));
  };
  try {
    if (req.method === 'POST' && req.url === '/run') {
      const { path: dir } = JSON.parse(await readBody(req));
      send(200, { port: await runBundle(dir) });
    } else if (req.method === 'GET' && req.url === '/status') {
      send(200, { port: serverPort });
    } else {
      send(404, { error: 'not found' });
    }
  } catch (e) {
    console.error(e);
    send(500, { error: String((e && e.message) || e) });
  }
});

control.listen(0, '127.0.0.1', () => {
  const portFile = path.join(dataDir, 'control.port');
  fs.writeFileSync(portFile + '.tmp', String(control.address().port));
  fs.renameSync(portFile + '.tmp', portFile);
  console.log('Cat node control listening on ' + control.address().port);
});

process.on('uncaughtException', err => {
  console.error('Caught exception: ' + (err && err.stack ? err.stack : err));
});

process.on('unhandledRejection', err => {
  console.error('unhandledRejection: ', err);
});
