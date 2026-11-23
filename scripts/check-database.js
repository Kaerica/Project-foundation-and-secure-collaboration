const { createProductStore } = require('../database')

async function main () {
  const productStore = createProductStore()

  try {
    await productStore.initialize()
    await productStore.checkConnection()

    const products = await productStore.listProducts()
    if (products.length === 0) {
      throw new Error('The database connected, but no inventory products were found.')
    }

    console.log(`Database connection OK; loaded ${products.length} product(s).`)
  } finally {
    await productStore.close()
  }
}

main().catch((error) => {
  console.error('Database check failed:', error)
  process.exitCode = 1
})
