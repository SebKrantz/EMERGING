# EMERGING: Multi-Regional Input–Output Table for the Global Emerging Economies

Analysis scripts for the EMERGING V2 MRIO database — 245 economies × 133 sectors, annual tables for 2015, 2018, 2021, and 2023.

## Dataset

The EMERGING database provides full-scale, near real-time multi-regional input–output (MRIO) tables covering 245 economies and 133 sectors (105 commodity + 30 service sectors). It also incorporates CO₂ emissions from fossil fuel combustion across seven energy types. All data are sourced from official national statistics to ensure consistency across regions and over time.

**Download:** [Zenodo — DOI: 10.5281/zenodo.19461860](https://doi.org/10.5281/zenodo.19461860)  
**License:** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

After downloading, place the `.mat` files in a `V2/` subdirectory.

## Citation

If you use this code or data, please cite:

**Article:**  
Huo, J., Chen, P., Hubacek, K., Zheng, H., Meng, J., & Guan, D. (2022). Full-scale, near real-time multi-regional input–output table for the global emerging economies (EMERGING). *Journal of Industrial Ecology*, 26, 1218–1232. https://doi.org/10.1111/jiec.13264

**Dataset (V2):**  
Huo, J., Wang, W., & Guan, D. (2026). Multi-regional Input–output Table for the Global Emerging Economies (EMERGING) V2 (2015–2023) [Data set]. Zenodo. https://doi.org/10.5281/zenodo.19461860

## Repository Contents

```
EMERGING/
├── classification/          # classification files and extraction scripts
├── import/                  # MRIO import, aggregation, and ICIO CSV export
└── decomposition/           # GVC decompositions and RVC indicator computation
```

### `classification/`

The curated classifications used by the V2 pipeline are `EMERGING_Sector_V2.xlsx` and `EMERGING_Country.xlsx`. These are hand-curated and differ from the raw labels embedded in the `.mat` files:

- **`EMERGING_Sector_V2.xlsx`** — curated sector classification for V2 (133 sectors). V2 removes the 27th sector of V1 (the aggregate HS-27 mineral fuels entry), since that aggregate is already disaggregated into detailed energy sub-sectors 99–105, reducing the total from 134 to 133 sectors.
- **`EMERGING_Country.xlsx`** — country classification with proper ISO3c codes for all 245 economies. As established by `Compare_Classifiction_with_V1.R`, the country list is consistent between V1 and V2.
- **`EMERGING_Sector.xlsx`** — raw V1 sector labels (134 sectors), kept for reference.
- **`EMERGING_Classification.xlsx`** — raw country and sector labels as embedded in the V2 `.mat` HDF5 files, extracted by `CountrySectorClass.R`. Used to verify the curated classifications above rather than as a primary input.

| Script | Language | Description |
|--------|----------|-------------|
| `CountrySectorClass.R` | R | Extracts raw country and sector labels from the V2 `.mat` HDF5 files → `EMERGING_Classification.xlsx` (reference only; the curated classifications are `EMERGING_Country.xlsx` and `EMERGING_Sector_V2.xlsx`) |
| `Compare_Classifiction_with_V1.R` | R | Verifies that the country classification is consistent between V1 and V2, and documents the sectoral difference (removal of the aggregate HS-27 sector in V2) |

### `import/`

| Script | Language | Description |
|--------|----------|-------------|
| `ImportEMERGING_V2.R` | R | Imports the V2 MRIO tables from `V2/*.mat`, aggregates to broad sectors using the curated classification, and saves to `EMERGING_Broad_Sectors.qs2` |
| `STATA_ICIO_CSVs_V2.R` | R | Writes the aggregated ICIO tables from `EMERGING_Broad_Sectors.qs2` to CSV files under `ICIO_CSV/` |

### `decomposition/`

| Script | Language | Description |
|--------|----------|-------------|
| `ICIO_decomp.jl` | Julia | GVC decompositions (KWW country-level, exporter-sector, bilateral-sector) using [ICIO.jl](https://github.com/SebKrantz/ICIO.jl); writes results to `ICIO_CSV/` |
| `ICIO_decomp.do` | Stata | Stata equivalent of the GVC decompositions |
| `rvc_indicators_V2.R` | R | Computes Regional Value Chain (RVC) indicators from decomposition outputs and produces figures under `figures/` |

## Workflow

```
1. classification/CountrySectorClass.R   # extract raw labels from .mat files (optional)
2. import/ImportEMERGING_V2.R            # import & aggregate MRIO tables → EMERGING_Broad_Sectors.qs2
3. import/STATA_ICIO_CSVs_V2.R          # write ICIO CSVs → ICIO_CSV/
4. decomposition/ICIO_decomp.jl         # GVC decompositions → ICIO_CSV/ (or ICIO_decomp.do for Stata)
5. decomposition/rvc_indicators_V2.R    # RVC indicators & figures
```

## Comparison with Other MRIO Databases

EMERGING was designed to address systematic gaps in existing global MRIO databases, particularly their inadequate coverage of emerging and developing economies. The table below summarises the main global MRIOs (see Huo et al. 2022, Table 1):

| Database | Countries | Sectors | Coverage | Annual? |
|----------|-----------|---------|----------|---------|
| **EMERGING V2** | **245** | **133** | **2015, 2018, 2021, 2023** | **No (4 yrs)** |
| **EMERGING V1** | **245** | **134** | **2010, 2015–2019** | **No (6 yrs)** |
| GLORIA | 164 regions | 97 | 1990–2019 | Yes |
| Eora | ~187 | 26–500+ (26 consistent) | 1990–2015 | Yes |
| EXIOBASE 3rx | 44+5 RoW | 163 | 1995–2022 | Yes |
| WIOD | 43+1 RoW | 56 | 2000–2014 | Yes |
| OECD ICIO | 66+RoW | 45 | 1995–2018 | Yes |
| GTAP 10 | 141+20 regions | 65 | 2004–2014 | No (3–4 yr) |
| FIGARO | 45+RoW | 64 | 2010–2019 | Yes |
| ADB | 62+RoW | 35 (harmonised) | 2000–2018 | Yes |
| IDE-JETRO | Asia-Pacific | 56–76 | 1975–2005 | No |

### Key advantages of EMERGING

**Broadest country coverage with consistent sectoral detail.** EMERGING covers 245 economies — more than any other global MRIO — with a uniform classification of 133 sectors across all of them. In contrast, Eora provides 26 consistent sectors across countries despite nominally covering up to 500+ sectors; WIOD covers only 43 countries; and EXIOBASE focuses mainly on the EU. GTAP provides only 3- to 4-year snapshots and IDE-JETRO tops out at 2005.

**Built from official national statistics.** 111 of the 245 economies have their own national IO data (in the form of IOTs, SUTs, or social accounting matrices) incorporated directly. Data are released by national statistical offices of 245 countries and reconciled with World Bank GDP and UN national accounts. GLORIA, by contrast, uses national data mainly as mathematical constraints to adjust an initial MRIO estimate rather than as primary inputs, which limits its accuracy for individual countries.

**Bilateral trade accuracy.** The compilation backbone is UN Comtrade bilateral goods trade data and WTO/WTIO bilateral service trade data, building a 3-D trade matrix of 245 economies × 133 sectors per year. This is calibrated against official national statistics and international economic data (World Bank, UN, FAO, IEA) through a multi-step reconciliation and disaggregation procedure. GTAP relies on older benchmark data (most recent release uses 2014 as base year), and OECD ICIO ignores differences between products and industries in its SUT construction.

**Near real-time timeliness.** V2 covers 2015, 2018, 2021, and 2023 — currently the most up-to-date global MRIO. Annual updates are enabled by a nine-module modular compilation framework that allows individual economies to be updated independently as new data become available, without recompiling the entire database.

**Detailed energy sector.** HS sector 27 (mineral fuels, oils, etc.) is disaggregated into seven energy sub-sectors (coal, oil, gas, electricity, gas manufacture & distribution, water, and related services) using HS 2002 4-digit codes. This energy detail is absent in most databases and enables accurate analysis of embodied energy and carbon in trade.

**Integrated CO₂ emissions.** V2 includes CO₂ emission inventories from fossil fuel combustion for each year, using IEA and CEAD data across seven energy types, making it directly usable for environmental footprint analysis without joining external datasets.

**Validation.** Production-based global value-added accounts differ by less than 1% across EMERGING, EXIOBASE 3rx, OECD, and Eora in aggregate. Larger differences emerge at the country level, especially for emerging economies (gaps of −60% to +90% across databases), primarily because other databases use each country's data only as a mathematical constraint rather than as a primary input — the main methodological distinction of EMERGING.

## Dependencies

**R:** [`fastverse`](https://fastverse.github.io/fastverse/), `rhdf5`, `readxl`, `openxlsx`, `qs2`, `decompr`, `africamonitor`, `ggplot2`, `igraph`, `pheatmap`, `RColorBrewer`, `migest`, `xtable`  
**Julia:** [`ICIO.jl`](https://github.com/SebKrantz/ICIO.jl), `CSV`, `DataFrames`  
**Stata:** standard IO tables support
