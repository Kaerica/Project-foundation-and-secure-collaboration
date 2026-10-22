# Inventory Manager

## Project Overview

The Inventory Manager is an application that helps users organize products, manage stock quantities, and identify products that need restocking.

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

- **Member 1:** Requirements, documentation, and team coordination.
- **Member 2:** Application setup, product listing, and product creation.
- **Member 3:** Quantity updates, low-stock warnings, and testing.

## Collaboration Workflow

Team members work on separate branches, commit their changes, and submit pull requests for review according to the repository rules.