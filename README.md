# Inventory Manager

> **Tagline:** Know your stock before you run out — simple inventory tracking for small shops in Rwanda.

## Project Overview

The Inventory Manager is an application that helps users organize products, manage stock quantities, and identify products that need restocking.

## Problem Statement

Many small retail businesses in Rwanda, such as school-supply shops, kiosks, and neighbourhood boutiques, still track their stock in paper notebooks or from memory. This makes it hard to know exactly how much of each product is left, so owners often run out of fast-selling items (for example notebooks and pens at the start of a school term) without noticing in time. Running out of stock means lost sales and unhappy customers, while over-ordering ties up limited cash.

The Inventory Manager gives these shop owners a simple digital record of their products, prices in Rwandan francs (RWF), and quantities, and automatically flags products that are running low so they can restock before they run out.

## Target Users

- **Small shop owners** (school-supply shops, kiosks, boutiques) who need an easy way to see what is in stock and what needs restocking.
- **Shop attendants** who record new products and update quantities after sales or deliveries.
- **Small business cooperatives** that want a shared, consistent way to track stock across members in the future.

## Technology Stack

- **Language:** JavaScript
- **Runtime:** Node.js
- **Package manager:** npm
- **Testing:** Node.js built-in test runner (`node --test`) with `node:assert`
- **Version control & collaboration:** Git, GitHub (Projects board, pull requests, branch protection)

## Project Objectives

- Organize product information in one place.
- Allow users to view and add products.
- Allow users to update product quantities.
- Identify products that are running low in stock.
- Prevent invalid product information from being saved.

## Main Features

### 1. View Products

Users can view the products recorded in the inventory.

### 2. Add Products

Users can add products with the required product information.

### 3. Update Stock Quantities

Users can update the quantity of an existing product.

### 4. Low-Stock Warnings

The application identifies products whose quantities fall below the low-stock threshold agreed upon by the team.

### 5. Input Validation

The application checks product information and displays clear error messages when invalid information is entered.

## Product Information

Each product contains the following fields:

- **ID:** A unique identifier for the product.
- **Name:** The name of the product.
- **Price:** The price per unit.
- **Quantity:** The number of units currently in stock.

## Minimum Requirements for Version 1

- Every product must have a unique ID.
- Product names must not be empty.
- Prices and quantities must not be negative.
- Users must be able to view and add products.
- Users must be able to update product quantities.
- The application must identify low-stock products.
- Invalid inputs must produce clear error messages.

## Product Storage

Products will use the storage method agreed upon by the team. All features will use the same product structure and storage approach so that product information remains consistent.

## Acceptance Criteria

- Users can view and add products.
- Each product follows the agreed structure.
- Product IDs are unique.
- Invalid product information is rejected with a clear error message.
- Users can update product quantities.
- Low-stock products are identified using the agreed threshold.
- The core features are tested.

## Team Responsibilities

| Member | Role | Responsibilities |
| --- | --- | --- |
| **Erica Karekezi** | Team Lead | Requirements, documentation, and team coordination |
| **Benigne Uwitonze** | Developer | Application setup, product listing, and product creation |
| **Owen Ganza** | Developer & Tester | Quantity updates, low-stock warnings, and testing |

## Collaboration Workflow

Team members work on separate branches, commit their changes, and submit pull requests for review according to the repository rules.

## Testing Results

The automated tests are run with:

```bash
npm test
```

The test suite currently covers:

- Required product fields and unique product IDs.
- Availability of the product display function.
- Successful updates to existing product quantities.
- Rejection of negative quantities.
- Rejection of non-integer quantities.
- Rejection of unknown product IDs.
- Low-stock detection for quantities below, exactly at, and above the threshold of 20.
- An inventory containing products above the low-stock threshold, which returns no low-stock products.

Latest test run:

- Tests run: 11
- Tests passed: 11
- Tests failed: 0
- Test suites failed: 0

The latest test run completed successfully. This result describes that run and is not a permanent guarantee; tests should be run again after future changes. Console output from `displayProducts()` and an actually empty inventory are not directly tested yet.

## Project Setup Instructions

### Prerequisites

Before running the Inventory Manager, make sure you have:

- [Node.js](https://nodejs.org/) installed.
- npm, which is included with Node.js.
- Git installed if you want to clone the project repository.

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/Kaerica/Project-foundation-and-secure-collaboration.git
   ```

2. Navigate to the project directory:

   ```bash
   cd Project-foundation-and-secure-collaboration
   ```

3. Install dependencies if the project has any listed in `package.json`:

   ```bash
   npm install
   ```

### Running the Application

Start the Inventory Manager using:

```bash
npm start
```

The application displays the products currently in the inventory, including their IDs, names, prices in Rwandan francs (RWF), and quantities.

### Running Tests

Run the automated test suite with:

```bash
npm test
```

The tests check product information, unique product IDs, and other inventory functionality.

### Troubleshooting

- If `npm` is not recognized, check that Node.js is installed and restart your terminal.
- If a command fails, confirm that you are in the project directory containing `package.json`.
- If tests fail, read the error output to identify which test needs attention.
