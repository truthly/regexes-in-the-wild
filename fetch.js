const { Cluster } = require('puppeteer-cluster');
const puppeteer = require('puppeteer-core'); // use puppeteer-core instead of puppeteer
const readline = require('readline');
const fs = require('fs');

(async () => {
  const cluster = await Cluster.launch({
    concurrency: Cluster.CONCURRENCY_CONTEXT,
    maxConcurrency: 8,

    // provide the puppeteer-core library
    puppeteer,
    // and provide executable path (in this case for a Chrome installation in Ubuntu)
    puppeteerOptions: {
      dumpio:true,
      executablePath: '/usr/local/bin/headless_shell',
    },
  });

  await cluster.task(async ({ page, data: url }) => {
    await page.goto(url);
    console.log('went to: ' + url);
  });

  const readInterface = readline.createInterface({
    input: fs.createReadStream('/home/regex/domains.txt')
  });
  readInterface.on('line', function(line) {
    cluster.queue(line);
  });

  await cluster.idle();
  await cluster.close();
})();
