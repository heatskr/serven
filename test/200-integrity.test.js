const path = require('path');
const fs = require('fs');
const faker = require('faker');

const { spawn } = require('child_process');

const cli = path.resolve('./cli.js');
const tmp = path.resolve('./tmp');
fs.mkdirSync(tmp, { recursive: true });
const ws = fs.mkdtempSync(`${tmp}${path.sep}`);
const base = path.join(ws, 'project001');

function shell(argv, cwd) {
  if (!cwd) {
    cwd = base;
  }
  return new Promise(function(resolve, reject){
    const out = [];
    const err = [];
    const cp = spawn(argv[0], argv.slice(1), {
      cwd: cwd,
      env: {
        PATH: process.env.PATH
      }
    });
    cp.stdout.on('data', function(chunk) {
      let data = chunk.toString('UTF-8');
      out.push(data);
    });
    cp.stderr.on('data', function(chunk) {
      let data = chunk.toString('UTF-8');
      err.push(data);
    });
    cp.on('exit', function(code, signal) {
      if (code) {
        throw new Error(err.join(''));
      } else {
        resolve(out.join(''));
      }
    })
  });
}

async function bootstrap() {
  await shell([cli, 'new', 'project001', '-f'], ws);
  await shell([cli, 'g', 'scaffold', '-f', 'person', 'name:string:r', 'age:integer:r']);
  await shell([cli, 'db', 'migrate']);
}

class PersonFactory
{
  static build() {
    return {
      name: `${faker.name.firstName()} ${faker.name.lastName()}`,
      age: (Math.random() * 100) | 0,
    }
  }
};

describe('Application Integrity', function(){
  let app;
  let agent;
  let personId;

  it('Bootstraps and run server', function(done) {
    this.timeout(60000);

    bootstrap().then(function(){
      process.chdir(base);
      app = new serven.Application(base);
      agent = request.agent(app);
      done();
    });
  });

  it('Searchs records', function(done){
    agent.get('/people')
    .set('Content-Type', 'application/json; charset=UTF-8')
    .expect(200)
    .then(function(res) {
      let body = JSON.parse(res.text);
      expect(Array.isArray(body.rows)).to.equal(true);
      expect(typeof body.count).to.equal('number');
      done();
    }).catch(function(error){
      done(error);
    });
  });

  it('Creates a new record', function(done){
    agent.post('/people')
    .set('Content-Type', 'application/json; charset=UTF-8')
    .send (JSON.stringify({
      // _csrf,
      person: PersonFactory.build()
    }))
    .expect(201)
    .then(function (res) {
      let loc = res.headers['location'];
      let pattern = /\/people\/\d{1,}/;
      expect(pattern.test (loc)).to.equal(true);
      let person = JSON.parse(res.text);
      personId = person.id;
      expect(personId > 0).to.equal(true);
    }).catch(function(error){
      console.error(error);
    }).finally(function(){
      done();
    });
  });

  it('Reads a record', function(done){
    agent.get(`/people/${personId}`)
    .set('Content-Type', 'application/json; charset=UTF-8')
    .expect(200)
    .then(function (res) {
      let person = JSON.parse(res.text);
      expect(personId == person.id).to.equal(true);
      done();
    }).catch(function(error){
      done(error);
    });
  });

  it('Updates a record', function(done){
    agent.put(`/people/${personId}`)
    .set('Content-Type', 'application/json; charset=UTF-8')
    .send (JSON.stringify({
      // _csrf,
      person: PersonFactory.build()
    }))
    .expect(200)
    .then(function (res) {
      let loc = res.headers['location'];
      let pattern = /\/people\/\d{1,}/;
      expect(pattern.test (loc)).to.equal(true);
      let person = JSON.parse(res.text);
      expect(personId == person.id).to.equal(true);
      done();
    }).catch(function(error){
      done(error);
    });
  });

  it('Deletes a record', function(done){
    agent.delete(`/people/${personId}`)
    .set('Content-Type', 'application/json; charset=UTF-8')
    .expect(204)
    .then(function (res) {
      done();
    }).catch(function(error){
      done(error);
    });
  });

  it('Finishes and clear server', function(done){
    fs.rmdirSync(tmp, { recursive: true });
    done();
  });
});
