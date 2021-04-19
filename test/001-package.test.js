
describe('Package', function () {
  it('Loads builtin classes', function(){
    expect(typeof serven).to.equal('object');
    expect(typeof serven.ACL).to.equal('function');
    expect(typeof serven.Annotations).to.equal('function');
    expect(typeof serven.Application).to.equal('function');
    expect(typeof serven.Asset).to.equal('function');
    expect(typeof serven.Config).to.equal('function');
    expect(typeof serven.Controller).to.equal('function');
    expect(typeof serven.Model).to.equal('function');
    expect(typeof serven.Router).to.equal('function');
  });
});
