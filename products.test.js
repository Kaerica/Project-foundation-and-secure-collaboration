
const test = require("node:test");
const assert = require("node:assert/strict");
const { products, displayProducts } = require("./products");

test("products have the required inventory fields", () => {
  assert.ok(products.length > 0);

  products.forEach((product) => {
    assert.ok(Number.isInteger(product.id));
    assert.equal(typeof product.name, "string");
    assert.equal(typeof product.price, "number");
    assert.equal(typeof product.quantity, "number");
  });
});

test("product IDs are unique", () => {
  const ids = products.map((product) => product.id);
  assert.equal(new Set(ids).size, ids.length);
});

test("displayProducts is a function", () => {
  assert.equal(typeof displayProducts, "function");
});
