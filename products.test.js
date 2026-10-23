
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  products,
  displayProducts,
  addProduct,
  updateQuantity,
  getLowStockProducts
} = require("./products");

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

test("adds a new product with a unique ID", () => {
  const originalLength = products.length;
  const originalIds = products.map((product) => product.id);

  try {
    const product = addProduct("Pencil", 300, 40);

    assert.equal(products.length, originalLength + 1);
    assert.equal(product.name, "Pencil");
    assert.equal(product.price, 300);
    assert.equal(product.quantity, 40);
    assert.ok(Number.isInteger(product.id));
    assert.ok(!originalIds.includes(product.id));
    assert.ok(products.includes(product));
  } finally {
    products.length = originalLength;
  }
});

test("trims extra spaces from a product name", () => {
  const originalLength = products.length;

  try {
    const product = addProduct("  Exercise Book  ", 1000, 15);
    assert.equal(product.name, "Exercise Book");
  } finally {
    products.length = originalLength;
  }
});

test("rejects an empty product name", () => {
  assert.throws(
    () => addProduct("   ", 500, 10),
    { message: "Product name must not be empty." }
  );
});

test("rejects a negative product price", () => {
  assert.throws(
    () => addProduct("Pencil", -100, 10),
    { message: "Price must be a non-negative number." }
  );
});

test("rejects an invalid product price", () => {
  assert.throws(
    () => addProduct("Pencil", "500", 10),
    { message: "Price must be a non-negative number." }
  );
});

test("rejects negative initial quantities", () => {
  assert.throws(
    () => addProduct("Pencil", 500, -1),
    { message: "Quantity must be a non-negative whole number." }
  );
});

test("rejects decimal initial quantities", () => {
  assert.throws(
    () => addProduct("Pencil", 500, 2.5),
    { message: "Quantity must be a non-negative whole number." }
  );
});

test("updates the quantity of an existing product", () => {
  const product = products[0];
  const originalQuantity = product.quantity;

  try {
    const message = updateQuantity(product.id, 25);

    assert.equal(product.quantity, 25);
    assert.equal(message, `Updated ${product.name} quantity to 25.`);
  } finally {
    product.quantity = originalQuantity;
  }
});

test("allows a product quantity to be updated to zero", () => {
  const product = products[0];
  const originalQuantity = product.quantity;

  try {
    const message = updateQuantity(product.id, 0);

    assert.equal(product.quantity, 0);
    assert.equal(message, `Updated ${product.name} quantity to 0.`);
  } finally {
    product.quantity = originalQuantity;
  }
});

test("rejects negative quantities", () => {
  assert.throws(
    () => updateQuantity(products[0].id, -1),
    { message: "Quantity must be a non-negative whole number." }
  );
});

test("rejects non-integer quantities", () => {
  assert.throws(
    () => updateQuantity(products[0].id, 2.5),
    { message: "Quantity must be a non-negative whole number." }
  );
});

test("rejects unknown product IDs", () => {
  assert.throws(
    () => updateQuantity(999, 10),
    { message: "Product not found." }
  );
});

test("identifies a product below the low-stock threshold", () => {
  const product = products[2];

  assert.equal(product.quantity, 10);
  assert.deepEqual(getLowStockProducts(), [product]);
});

test("identifies a product exactly at the low-stock threshold", () => {
  const product = products[0];
  const originalQuantity = product.quantity;

  try {
    updateQuantity(product.id, 20);
    assert.ok(getLowStockProducts().includes(product));
  } finally {
    product.quantity = originalQuantity;
  }
});

test("does not identify a product above the low-stock threshold", () => {
  const product = products[0];
  const originalQuantity = product.quantity;

  try {
    updateQuantity(product.id, 21);
    assert.ok(!getLowStockProducts().includes(product));
  } finally {
    product.quantity = originalQuantity;
  }
});

test("returns no products when all quantities are above the threshold", () => {
  const originalQuantities = products.map((product) => product.quantity);

  try {
    products.forEach((product) => {
      product.quantity = 21;
    });

    assert.deepEqual(getLowStockProducts(), []);
  } finally {
    products.forEach((product, index) => {
      product.quantity = originalQuantities[index];
    });
  }
});
