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
- **Containerization:** Docker and Docker Compose
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

Products are stored in an in-memory JavaScript array. No database is currently required for this application. Product data resets when the application or its Docker container exits.

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
- Adding products with unique IDs.
- Trimming extra spaces from product names.
- Rejection of empty product names.
- Rejection of negative and invalid product prices.
- Rejection of negative and decimal initial quantities.
- Successful updates to existing product quantities.
- Rejection of negative quantities.
- Rejection of non-integer quantities.
- Rejection of unknown product IDs.
- Low-stock detection for quantities below, exactly at, and above the threshold of 20.
- An inventory containing products above the low-stock threshold, which returns no low-stock products.

Latest local test run:

- Tests run: 19
- Tests passed: 19
- Tests failed: 0
- Tests skipped: 0

## Project Setup Instructions

### Prerequisites

Before running the Inventory Manager, make sure you have:

- [Node.js](https://nodejs.org/) installed.
- npm, which is included with Node.js.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running if you want to use Docker Compose.
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

3. Install dependencies:

   ```bash
   npm install
   ```

### Running the Application with Node.js

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

The tests check product information, unique product IDs, product creation, quantity updates, validation, and low-stock functionality.

### Running with Docker Compose

Docker Desktop must be installed and running before using Docker Compose.

Docker Compose builds the application from the project's `Dockerfile` and starts the Inventory Manager with `NODE_ENV=production`.

Validate the Compose configuration without starting the application:

```bash
docker compose config
```

Build the Docker image:

```bash
docker compose build
```

Start the application and view its console output:

```bash
docker compose up
```

The application is a console program, so it does not expose a web port. It does not require a database, cache, or persistent volume. It uses the default Compose network. Its current inventory is stored in memory and is reset when the container exits.

Stop and remove the Compose container and network:

```bash
docker compose down
```

The `.dockerignore` file prevents unnecessary files such as `node_modules`, Git metadata, logs, local environment files, and test coverage from being sent to the Docker build context.

### Troubleshooting

- If `npm` is not recognized, check that Node.js is installed and restart your terminal.
- If Docker commands cannot connect to the Docker API, open Docker Desktop and wait until the Docker engine is running.
- If a command fails, confirm that you are in the project directory containing `package.json`, `Dockerfile`, and `docker-compose.yml`.
- If tests fail, read the error output to identify which test needs attention.
- If the Docker build fails, check the Dockerfile and confirm that Docker Desktop is running.
- If the Compose application does not print inventory output, run `docker compose logs inventory-manager`.

Task sheet: https://docs.google.com/spreadsheets/d/1TCxL-WfICCbLBdjP55zqJglPlL9q4Nc1i03C_sfZfcA/edit?usp=sharing

## Continuous Integration

GitHub Actions automatically checks code changes by running linting,
automated tests, and a Docker image build.