# Global Deforestation Analysis (1990–2016) — SQL

A SQL analysis of global forest loss for **ForestQuery**, a (fictional) organization
working to combat deforestation. Using World Bank data on forest area and total land
area by country and year, this project joins three source tables, builds a reusable
analytical view, and answers a series of questions about where forest is being lost,
where it is recovering, and which countries most need attention.

> Originally completed as the SQL capstone in Udacity's Data Analysis program, then
> reworked here with a cleaned query set and a standalone analytical report.

---

## 🎯 The question

Between 1990 and 2016, is the world gaining or losing forest — and if losing, *where*,
*how fast*, and *which countries* should a conservation team prioritize?

## 🗂 The data

Three tables from the World Bank:

| Table | Description |
|-------|-------------|
| `forest_area` | Forest area (sq km) by country and year |
| `land_area` | Total land area by country and year |
| `regions` | Country → region and income-group mapping |

The tables are joined into a single `forestation` **view** that adds a calculated
`percent_forest` column (forest area ÷ total land area), which every downstream query
builds on.

## 🛠 Tools

- **MySQL** — data loading, joins, and analysis
- Techniques used: `JOIN`, `VIEW`, CTEs (`WITH`), subqueries, window-style ranking,
  `CASE` bucketing, `NULL` handling on real-world gapped data

## 📊 Key findings

- **The world lost ~1.32 million sq km of forest** between 1990 and 2016 — a **3.2%**
  decline, an area slightly larger than the entire country of Peru.
- Global forest cover fell from **32.42%** of land area in 1990 to **31.38%** in 2016.
- **Only two regions lost forest**: Latin America & Caribbean and Sub-Saharan Africa.
  Every other region gained — but these two lost enough to drag the global total down.
- **Biggest absolute loss:** Brazil, Indonesia, Myanmar, Nigeria, Tanzania.
- **Biggest percentage loss:** Togo (−75.45%), Nigeria, Uganda, Mauritania, Honduras —
  four of the top five are in Sub-Saharan Africa.
- **Nigeria is the only country in the top five for *both* absolute and percentage loss**,
  making it a clear priority.
- **Success story:** China *added* ~527,000 sq km of forest — far more than any other country.

Full narrative, tables, and recommendations are in
[`report/forestquery_report.md`](report/forestquery_report.md).

## 📁 Repository structure
forestquery-deforestation/
├── README.md                     
├── sql/
│   └── forestquery_analysis.sql  
├── report/
│   └── forestquery_report.md    
└── data/
    └── (your CSVs)               
