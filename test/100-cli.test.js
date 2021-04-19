const { spawn } = require('child_process');
const os = require('os');
const fs = require('fs');
const path = require('path');

describe('Command Line Interface', function(){
  const cli = path.resolve('./cli.js');
  const tmp = path.resolve('./tmp');
  fs.mkdirSync(tmp, { recursive: true });
  const ws = fs.mkdtempSync(`${tmp}${path.sep}`);
  const base = path.join(ws, 'project001');


  it('Shows current version', function(done){
    let version;
    let cp = spawn(cli, ['--version']);
    cp.stdout.on('data', function(chunk){
      version = chunk.toString('UTF-8');
    });
    cp.on('exit', function(code){
      expect(code).to.equal(0);
      expect(/^\d+\.\d+\.\d+\s{0,}$/.test(version)).to.equal(true);
      done();
    });
  });

  it('Bootstraps a new application',  function(done) {
    this.timeout(20000);

    let cp = spawn(cli, [
      'new', 'project001', '--database=sqlite'
    ], {
      cwd: ws,
      env: {
        PATH: process.env.PATH
      }
    });

    cp.on('exit', function(code, signal) {
      expect(code).to.equal(0);
      expect(signal).to.equal(null);

      let files = [
        'node_modules/serven',
        'node_modules/sqlite3',
        'app/assets/scripts/application.coffee',
        'app/assets/stylesheets/application.styl',
        'app/views/main/home.pug',
        'app/controllers/Main.coffee',
        'config/acl.coffee',
        'config/assets.coffee',
        'config/middleware.coffee',
        'config/routes.coffee',
        'config/sequelize.coffee',
        'config/session.coffee',
        'data/migrate.d',
        'data/seed.d',
        'data/storage',
        'test/_spec.test.js',
        'tmp/logs',
        'tmp/sessions',
        'tmp/uploads',
      ];

      for (file of files) {
        let filename = path.join(base, file);
        let exists = fs.existsSync(filename);
        if (!exists) {
          console.log(filename);
        }
        expect(exists).to.equal(true);
      }

      done();
    });
  });

  it('Generates a simple scaffold', function(done) {
    this.timeout(20000);

    let cp = spawn(cli, [
      'generate', 'scaffold', 'category', 'name:string:required:unique'
    ], {
      cwd: base
    });

    cp.on('exit', function(code, signal) {
      expect(code).to.equal(0);
      expect(signal).to.equal(null);

      let files = [
        'app/assets/scripts/categories.coffee',
        'app/assets/stylesheets/categories.styl',
        'app/models/Category.coffee',
        'app/views/categories/edit.pug',
        'app/views/categories/form.pug',
        'app/views/categories/new.pug',
        'app/views/categories/read.pug',
        'app/views/categories/search.pug',
        'app/controllers/Categories.coffee',
        'app/helpers/Categories.coffee',
      ];

      for (file of files) {
        let filename = path.join(base, file);
        expect(fs.existsSync(filename)).to.equal(true);
      }

      done();
    });
  });

  it('Generates a relationship based scaffold', function(done) {
    this.timeout(20000);

    let cp = spawn(cli, [
      'generate',
      'scaffold',
      'product',
      'name:string:required',
      'price:decimal{10,2}:required',
      'category:references'
    ], {
      cwd: base
    });

    cp.on('exit', function(code, signal){
      expect(code).to.equal(0);
      expect(signal).to.equal(null);

      done();
    });
  });

  it('Displays migration status', function(done) {
    this.timeout(20000);

    let cp = spawn(cli, [
      'database',
      'status'
    ], {
      cwd: base
    });

    output = "";

    cp.stdout.on('data', function(chunk) {
      output += chunk.toString('UTF-8');
    });

    cp.on('exit', function(code, signal){
      expect(code).to.equal(0);
      expect(signal).to.equal(null);

      expect(output).to.contain('create_categories');
      expect(output).to.contain('create_products');

      done();
    });
  });

  it('Applies database changes', function(done) {
    this.timeout(20000);

    let cp = spawn(cli, [
      'database',
      'migrate'
    ], {
      cwd: base
    });

    cp.on('exit', function(code, signal){
      expect(code).to.equal(0);
      expect(signal).to.equal(null);

      done();
    });
  });

  it('Starts HTTP server up', function(done) {
    this.timeout(20000);

    port = 3000 + (Math.random() * 100 | 0)

    let cp = spawn(cli, [
      'server',
      `--port=${port}`
    ], {
      cwd: base
    });

    cp.on('spawn', function(){
      expect(!!cp.pid).to.equal(true);
      setTimeout(function(){
        cp.kill();
      }, 2000);
    });

    cp.on('exit', function(code, signal){
      expect(code).to.equal(null);
      expect(signal).to.equal('SIGTERM');

      done();
    });
  });

  it('Resets database information', function(done){
    this.timeout(20000);

    let cp = spawn(cli, [
      'database',
      'reset',
    ], {
      cwd: base
    });

    cp.on('exit', function(code, signal){
      expect(code).to.equal(0);
      expect(signal).to.equal(null);
      done();
    });
  });

  it('Reverts database schema', function(done){
    this.timeout(20000);

    let cp = spawn(cli, [
      'database',
      'rollback',
      '2'
    ], {
      cwd: base
    });

    cp.on('exit', function(code, signal){
      expect(code).to.equal(0);
      expect(signal).to.equal(null);
      done();
    });
  });

  it('Removes last generated scaffold', function(done){
    this.timeout(20000);

    let cp = spawn(cli, [
      'destroy',
      'scaffold',
      'product'
    ], {
      cwd: base
    });

    cp.on('exit', function(code, signal){
      expect(code).to.equal(0);
      expect(signal).to.equal(null);
      done();
    });
  });

  it('Removes first generated scaffold', function(done){
    this.timeout(20000);

    let cp = spawn(cli, [
      'destroy',
      'scaffold',
      'category'
    ], {
      cwd: base
    });

    cp.on('exit', function(code, signal){
      expect(code).to.equal(0);
      expect(signal).to.equal(null);

      let files = [
        'app/assets/scripts/categories.coffee',
        'app/assets/stylesheets/categories.styl',
        'app/models/Category.coffee',
        'app/views/categories/edit.pug',
        'app/views/categories/form.pug',
        'app/views/categories/new.pug',
        'app/views/categories/read.pug',
        'app/views/categories/search.pug',
        'app/controllers/Categories.coffee',
        'app/helpers/Categories.coffee',
      ];

      for (file of files) {
        let filename = path.join(base, file);
        expect(fs.existsSync(filename)).to.equal(false);
      }

      fs.rmdirSync(ws, { recursive: true });

      done();
    });
  });

});
