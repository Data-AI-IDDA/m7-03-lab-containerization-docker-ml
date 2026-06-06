![logo_ironhack_blue 7](https://user-images.githubusercontent.com/23629340/40541063-a07a0a8a-601a-11e8-91b5-2f13e4e6b441.png)

# Lab | Time Series Visualization and Lightweight Modeling

## Overview

This lab focuses on time series exploration, visualization, and simple modeling using a currency conversion rate dataset. You will load a multi‑currency time series, validate dates and numeric types, create informative plots, compute rolling features, and build a basic baseline model to reason about changes over time. The emphasis is on correctness, clear reasoning, and repeatable steps.

## Learning Goals

By the end of the lab, you should be able to load and validate time series data, create meaningful visualizations, compute rolling statistics, and build a simple baseline model with clear evaluation checks.

## Setup and Context

You will use the CSV dataset included in this repository: `data_safe_copy.csv`. The file contains daily currency conversion rates with a `Date` column and multiple currency pairs. Work in a notebook named `m1-08-viz-time-series-advanced-modeling-lab.ipynb`.

## Requirements

- Fork this repository to your own GitHub account.
- Clone your fork to your machine.
- Use the included CSV file `data_safe_copy.csv` from the lab repository.
- Make sure you can open and run Jupyter notebooks (for example via Jupyter Lab or VS Code).

## Getting Started

- Create a new notebook and name it `m1-08-viz-time-series-advanced-modeling-lab.ipynb`.
- Confirm you can successfully load the CSV before you start plotting.
- Before you submit, restart your kernel and run the notebook **top to bottom**.

## Tasks

### Task 1: Load and validate the time series

Load the CSV into a DataFrame named `fx`. Parse `Date` as datetime and set it as the index. Confirm the index is sorted in ascending order and that all rate columns are numeric. Print the first five rows and the last five rows to verify the time span.

### Task 2: Create two focused visualizations

Select two currency pairs, one that ends with `USD` and one that begins with `USD`. Create a line plot for each pair over time. Add clear titles and labels. Then create a third plot that shows both series together on the same axes so you can compare their movement directionally.

### Task 3: Rolling features and validation

Compute a 7‑day rolling mean and a 7‑day rolling standard deviation for the two currency pairs you selected. Store the rolling series with clear names. Print the first ten rows of the rolling results and confirm that missing values appear only where the window is incomplete.

### Task 4: Simple baseline model

Build a one‑step‑ahead baseline forecast for one selected currency pair by shifting the series by one day. Create a new column `baseline_pred` and compute the absolute error between the actual value and the baseline prediction. Then compute the mean absolute error and print it.

Add a validation check that confirms the number of non‑missing predictions equals the number of rows minus one.

### Task 5: Short report with checks

Write a small report dictionary that includes the chosen currency pairs, the rolling window size, the mean absolute error from the baseline model, and the date range of the dataset. Print the report and include one explicit check, such as confirming that the rolling window size you used matches the value in the report.

## Common Pitfalls and Debugging Notes

A common mistake is forgetting to parse the date column or set it as the index, which makes time‑based plots misleading. Another frequent issue is silently treating numeric columns as strings; always confirm dtypes after loading. If rolling results look wrong, check that the index is sorted and that the window size is correct.

## Submission

### What to submit

Submit the following files:
- The notebook file `m1-08-viz-time-series-advanced-modeling-lab.ipynb`

### Definition of done (checklist)

Before you submit, make sure:

- [ ] The notebook runs **top to bottom** without errors after a kernel restart.
- [ ] `Date` is parsed as datetime, set as the index, and sorted ascending.
- [ ] You created the requested plots with titles/labels and selected the required currency pair patterns.
- [ ] Rolling mean/std are computed and validated (missing values only where the window is incomplete).
- [ ] Baseline forecast and MAE are computed on aligned data with the requested row-count check.
- [ ] The notebook is saved and included in your git commit.

### How to submit (Git workflow)

- When you’re done, make sure all changes are saved, then run:

```bash
git add .
git commit -m "Solved m1-08 lab"
git push -u origin HEAD
```

- Make a pull request.
- Paste the link to your pull request in the Student Portal.

## Evaluation Criteria

Your work will be evaluated on correctness, clarity, and structure. Correctness means your plots and rolling calculations reflect the intended logic and your baseline model errors are computed on aligned data. Clarity means your code is readable and your variables are clearly named. Structure means the notebook runs cleanly from top to bottom with each task completed in order and with visible outputs.
