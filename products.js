
const products = [
  {
    id: 1,
    name: "Notebook",
    price: 2000,
    quantity: 50
  },
  {
    id: 2,
    name: "Pen",
    price: 500,
    quantity: 100
  },
  {
    id: 3,
    name: "School Bag",
    price: 15000,
    quantity: 10
  }
];

const LOW_STOCK_THRESHOLD = 20;

function displayProducts() {
  console.log("\n===== INVENTORY MANAGER =====");
  console.log("Products currently in inventory:\n");

  if (products.length === 0) {
    console.log("No products found.");
    return;
  }

  products.forEach((product) => {
    console.log("------------------------------");
    console.log(`ID: ${product.id}`);
    console.log(`Name: ${product.name}`);
    console.log(`Price: RWF ${product.price.toLocaleString()}`);
    console.log(`Quantity: ${product.quantity}`);
  });

  console.log("------------------------------");
  console.log(`Total products: ${products.length}`);
}

function addProduct(name, price, quantity) {
  if (typeof name !== "string" || name.trim() === "") {
    throw new Error("Product name must not be empty.");
  }

  if (typeof price !== "number" || !Number.isFinite(price) || price < 0) {
    throw new Error("Price must be a non-negative number.");
  }

  if (!Number.isInteger(quantity) || quantity < 0) {
    throw new Error("Quantity must be a non-negative whole number.");
  }

  const nextId =
    products.length === 0
      ? 1
      : Math.max(...products.map((product) => product.id)) + 1;

  const product = {
    id: nextId,
    name: name.trim(),
    price,
    quantity
  };

  products.push(product);

  return product;
}

function updateQuantity(productId, newQuantity) {
  const product = products.find((item) => item.id === productId);

  if (!product) {
    throw new Error("Product not found.");
  }

  if (!Number.isInteger(newQuantity) || newQuantity < 0) {
    throw new Error("Quantity must be a non-negative whole number.");
  }

  product.quantity = newQuantity;

  return `Updated ${product.name} quantity to ${product.quantity}.`;
}

function getLowStockProducts() {
  return products.filter(
    (product) => product.quantity <= LOW_STOCK_THRESHOLD
  );
}

module.exports = {
  products,
  displayProducts,
  addProduct,
  updateQuantity,
  getLowStockProducts
};
