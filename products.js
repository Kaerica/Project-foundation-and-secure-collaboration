
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

module.exports = {
  products,
  displayProducts
};
