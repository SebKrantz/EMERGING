# ---------------------------------------------------------------------------
#      RVC Indicators — EMERGING MRIO v2 (https://zenodo.org/records/19461860)
# ---------------------------------------------------------------------------
# Port of code/rvc_indicators.R (Africa-Regional-Integration repo) to the
# EMERGING v2 tables. The methodology is unchanged (see paper section "Regional
# Value Chains"); only the data sources, sector classification, and benchmark
# years differ:
#   * Tables:         EMERGING_Broad_Sectors.qs2        (built by ImportEMERGING_V2.R)
#   * Decompositions: ICIO_CSV/EMERGING_Broad_Sectors/EM_GVC_SEC_BM19.csv (ICIO_decomp.jl)
#   * Classification: EMERGING_Sector_V2.xlsx
#   * Benchmark years: 2015, 2018, 2021, 2023  (v1 used yearly 2010-2019, 2015-19 avg)
#
# NB: In v2 the Julia decomposition writes `from_sector` as the broad-sector
# CODE (e.g. "AFF"); the v1 Stata pipeline wrote an integer index 1..18. Hence
# we rename `from_sector` -> `sector_code` instead of joining on an integer.
# Also, no precomputed decompr object exists for v2, so the Leontief
# value-added-in-exports (FVAX) object is built from the .qs2 tables and cached.
# ---------------------------------------------------------------------------

library(fastverse)
fastverse_extend(qs2, readxl, africamonitor, ggplot2, decompr, igraph, pheatmap, RColorBrewer, migest, xtable)
set_collapse(mask = c("manip", "helper", "special"), nthreads = 2)

setwd("~/Documents/Data/EMERGING")

# Repo providing shared plotting helpers, the REC classification, and the shapefile
REPO <- "/Users/sebastiankrantz/Documents/World Bank/Africa-Regional-Integration"
source(file.path(REPO, "code/helpers.R"))
fastverse_conflicts()

# Outputs are written locally (EMERGING folder) to keep v2 results separate from v1
dir.create("figures/GVC", recursive = TRUE, showWarnings = FALSE)
dir.create("results", showWarnings = FALSE)

MAN <- c("FBE", "TEX", "WAP", "PCM", "MPR", "ELM", "TEQ", "MAN")

RECs <- readxl::read_xlsx(file.path(REPO, "data/Africa_REC_classification.xlsx"))

fastverse_extend(sf, tmap)
fastverse_conflicts()
africa_map <- st_read("/Users/sebastiankrantz/Documents/Data/Shapefiles/Africa_Countries") |> st_make_valid()
# Natural Earth Africa omits Mauritius and Seychelles (not on mainland)
if (!all(c("MUS", "SYC") %in% africa_map$ISO_3DIGIT)) {
  if (!requireNamespace("rnaturalearth", quietly = TRUE)) {
    install.packages(c("rnaturalearth", "rnaturalearthdata"), repos = "https://cloud.r-project.org")
  }
  extra <- rnaturalearth::ne_countries(scale = 50, returnclass = "sf")
  extra <- extra[extra$iso_a3 %in% c("MUS", "SYC"), ]
  extra$ISO_3DIGIT <- extra$iso_a3
  for (col in setdiff(names(africa_map), names(extra))) extra[[col]] <- NA
  for (col in setdiff(names(extra), names(africa_map))) africa_map[[col]] <- NA
  africa_map <- rbind(africa_map, extra[names(africa_map)])
}
minlon = -20; minlat = -34; maxlon = 52; maxlat = 36
bbox <- st_bbox(c(xmin = minlon, ymin = minlat, xmax = maxlon, ymax = maxlat), crs = st_crs(4326))

tm_map_layout <- function() tm_layout(
  frame = FALSE,
  legend.text.size = 0.9,
  legend.title.size = 1.2,
  legend.position = c("left", "bottom"),
  legend.frame = FALSE,
  legend.bg = FALSE,
  legend.width = 0.18,
  inner.margins = c(0.02, 0.02, 0.26, 0.02)
)

# -----------------------------------
### EMERGING v2 Broad Sectors

# Broad-sector classification (v2): code + full name
EM_SEC_BS <- read_xlsx("EMERGING_Sector_V2.xlsx") |>
             gvr("Broad") |> funique() |> rename(tolower) |> rm_stub("broad_")

# Exporter-sector decomposition. In v2, `from_sector` already holds the broad-
# sector code (string), so we rename rather than join on an integer index.
EM_BS <- list(SEC = fread("ICIO_CSV/EMERGING_Broad_Sectors/EM_GVC_SEC_BM19.csv") |>
                   rename(sector_code = from_sector) |>
                   join(EM_SEC_BS, on = "sector_code") |>
                   colorder(year, from_region, sector_code, sector))

########################################
# Leontief Decomposition & African Shares
########################################

# Build (and cache) the Leontief VA-in-exports object from the v2 tables.
# Mirrors the commented block in code/gvc_indicators.R that produced the v1
# decompr/EMERGING_Broad_Sectors_decomps.qs, but from EMERGING_Broad_Sectors.qs2.
decomp_file <- "decompr/EMERGING_Broad_Sectors_decomps_V2.qs2"
if (file.exists(decomp_file)) {
  decomps <- qs_read(decomp_file)
} else {
  EM <- qs_read("EMERGING_Broad_Sectors.qs2")
  decomps <- lapply(EM$DATA, function(x)
    load_tables_vectors(x = x$T, y = x$FD, k = EM$Regions$ISO3,
                        i = EM$Sectors$Broad_Sector_Code, o = x$X, v = x$VA))
  dir.create("decompr", showWarnings = FALSE)
  qs_save(decomps, decomp_file)
  rm(EM); gc()
}

# Average forward VA-in-exports (FVAX) across the v2 benchmark years
yrs <- names(decomps)                       # "2015" "2018" "2021" "2023"
leontief <- leontief(decomps[[yrs[1L]]]) |> rename(tolower) |> qDT()
for (i in yrs[-1L]) {
  leontief$fvax %+=% leontief(decomps[[i]])$FVAX
}
leontief$fvax %/=% length(yrs)
rm(decomps); gc()

# Sector-level African shares in I2E and E2R
I2E_AFR_SEC <- leontief |>
  subset(source_country != using_country & using_country %in% am_countries$ISO3) |>
  group_by(sector = using_industry, from_africa = source_country %in% am_countries$ISO3) |>
  select(I2E = fvax) |> fsum() |>
  mutate(I2E_AFR = fsum(I2E, sector, TRA = "/"))

E2R_AFR_SEC <- leontief |>
  subset(source_country != using_country & source_country %in% am_countries$ISO3) |>
  group_by(sector = source_industry, to_africa = using_country %in% am_countries$ISO3) |>
  select(E2R = fvax) |> fsum() |>
  mutate(E2R_AFR = fsum(E2R, sector, TRA = "/"))

GVC_SEC_AGG <- join(I2E_AFR_SEC, E2R_AFR_SEC, on = c("sector", "from_africa" = "to_africa")) |> rm_stub("from_")
rm(I2E_AFR_SEC, E2R_AFR_SEC)

# Sector-level decomposition (v2 benchmark-year average)
EM_BS_AGG_SEC <- EM_BS$SEC |>
  subset(year > 2010 & from_region %in% am_countries$ISO3,
         sector_code, sector, from_region, vax, davax, ref, ddc, fva, fdc) |>
  group_by(sector_code, sector, from_region) |> fmean() |>
  group_by(sector_code, sector) |> num_vars() |> fsum() |>
  subset(order(vax + fva - davax, decreasing = TRUE)) |>
  transform(ndavax = vax - davax, davax = NULL, vax = NULL,
            sector_code = qF(sector_code, sort = FALSE)) |>
  colorder(sector_code, sector, ndavax) |>
  rename(toupper, cols = is.numeric)

########################################
# Sector-Level RVCs
########################################

GVC_SEC_AGG |>
  subset(africa, sector, E2R = E2R_AFR, I2E = I2E_AFR) |>
  pivot("sector") |>
  ggplot(aes(x = sector, y = value, fill = variable)) +
    geom_bar(stat = "identity", position = position_dodge(0.9)) +
    scale_y_continuous(n.breaks = 7, expand = expansion(mult = c(0, 0.03)),
                       labels = scales::percent) +
    scale_fill_manual(values = c("orange", "dodgerblue4")) +
    labs(x = "Sector", y = "African Share in African GVC Exports", fill = "Term") +
    pretty_plot("right") +
    theme(axis.text.x = element_text(angle = 270, hjust = 0, vjust = 0.5))

ggsave("figures/GVC/EM_BS_KWW_EXT_SEC_AFR.pdf", width = 6, height = 4)

EM_BS_AGG_SEC |>
  join(subset(GVC_SEC_AGG, africa, -africa),
       on = c("sector_code" = "sector")) |>
  mutate(across(c(NDAVAX, REF), `*`, E2R_AFR),
         across(c(DDC, FVA, FDC), `*`, I2E_AFR)) |>
  subset(order(NDAVAX + FVA, decreasing = TRUE)) |>
  mutate(sector_code = qF(sector_code, sort = FALSE)) |>
  select(sector_code:FDC) |>
  pivot(1:2) |>
  ggplot(aes(x = sector_code, y = value, fill = variable)) +
    geom_bar(stat = "identity", position = "stack") +
    scale_y_continuous(n.breaks = 7, expand = expansion(mult = c(0, 0.03)),
                       labels = scales::label_currency(suffix = "B", scale = 1e-3)) +
    scale_fill_manual(values = c("orange", "yellow2", "green2", "dodgerblue4", "dodgerblue")) +
    labs(x = "Sector", y = "RVC Related Exports Contents", fill = "Term") +
    pretty_plot("right") +
    theme(axis.text.x = element_text(angle = 270, hjust = 0, vjust = 0.5))

ggsave("figures/GVC/EM_BS_KWW_EXT_SEC_GVC_AFR.pdf", width = 6, height = 4)

########################################
# Country-Level RVCs
########################################

EM_BS_AGG <- EM_BS$SEC |>
  subset(year > 2010 & from_region %in% am_countries$ISO3,
         sector_code, sector, from_region, vax, davax, ref, ddc, fva, fdc) |>
  group_by(sector_code, sector, from_region) |> fmean() |>
  group_by(country = from_region) |> num_vars() |> fsum() |>
  subset(order(vax + fva - davax, decreasing = TRUE)) |>
  transform(ndavax = vax - davax, davax = NULL, vax = NULL,
            country = qF(country, sort = FALSE)) |>
  colorder(country, ndavax) |>
  rename(toupper, cols = is.numeric)

I2E_AFR <- leontief |>
  subset(source_country != using_country & using_country %in% am_countries$ISO3) |>
  group_by(using_country, using_industry, from_africa = source_country %in% am_countries$ISO3) |>
  select(fvax) |> fsum() |>
  mutate(I2E_AFR = replace_na(fsum(fvax, list(using_country, using_industry), TRA = "/"))) |>
  rename(fvax = I2E) |> rm_stub("using_")

E2R_AFR <- leontief |>
  subset(source_country != using_country & source_country %in% am_countries$ISO3) |>
  group_by(source_country, source_industry, to_africa = using_country %in% am_countries$ISO3) |>
  select(fvax) |> fsum() |>
  mutate(E2R_AFR = replace_na(fsum(fvax, list(source_country, source_industry), TRA = "/"))) |>
  rename(fvax = E2R) |> rm_stub("source_")

GVC_SEC_AGG <- join(I2E_AFR, E2R_AFR, on = c("country", "industry", "from_africa" = "to_africa")) |>
               rename(industry = sector, from_africa = africa)
rm(I2E_AFR, E2R_AFR)

GVC_SEC_AGG |>
  collap(I2E + E2R ~ country + africa, fsum) |>
  transformv(c(I2E, E2R), fsum, country, TRA = "/", apply = FALSE) |>
  subset(africa, country, E2R, I2E) |>
  pivot("country") |>
  ggplot(aes(x = country, y = value, fill = variable)) +
  geom_bar(stat = "identity", position = position_dodge(0.9)) +
  scale_y_continuous(n.breaks = 7, expand = expansion(mult = c(0, 0.03)),
                     labels = scales::percent) +
  scale_fill_manual(values = c("orange", "dodgerblue4")) +
  labs(x = "Country", y = "African Share in Countries' GVC Exports", fill = "Term") +
  pretty_plot("right") +
  theme(axis.text.x = element_text(angle = 270, hjust = 0, vjust = 0.5))

ggsave("figures/GVC/EM_BS_KWW_EXT_CTRY_AFR.pdf", width = 10, height = 4)

GEXP <- leontief |> rm_stub("using_") |> collap(fvax ~ country, fsum)

EM_BS_AGG_AFR <- EM_BS_AGG |>
  join(collap(GVC_SEC_AGG, I2E + E2R ~ country + africa, fsum) |>
         transform(I2E_AFR = fsum(I2E, country, TRA = "/"),
                   E2R_AFR = fsum(E2R, country, TRA = "/")) |>
         subset(africa, -africa),
       on = "country") |>
  mutate(across(c(NDAVAX, REF), `*`, E2R_AFR),
         across(c(DDC, FVA, FDC), `*`, I2E_AFR))

RVC_CTRY <- GVC_SEC_AGG |>
  subset(africa) |>
  collap(I2E + E2R ~ country, fsum) |>
  join(GEXP, on = "country") |>
  tfmv(c(I2E, E2R), `/`, fvax) |>
  join(compute(EM_BS_AGG_AFR, RVC = psum(NDAVAX, REF, DDC, FVA, FDC), keep = "country"), on = "country") |>
  subset(order(I2E + E2R, decreasing = TRUE)) |>
  mutate(country = qF(country, sort = FALSE),
         label = paste0("$", signif(RVC, 3), "M"))

RVC_CTRY |>
  pivot(c("country", "label"), values = .c(E2R, I2E)) |>
  ggplot(aes(x = country, y = value, fill = variable)) +
    geom_bar(stat = "identity", position = "stack") +
    geom_text(data = mtt(RVC_CTRY, Y = I2E + E2R), aes(x = country, y = Y, label = label),
              nudge_y = 0.002, hjust = 0, angle = 90, size = 3, inherit.aes = FALSE) +
    scale_y_continuous(n.breaks = 7, expand = expansion(mult = c(0, 0.15)),
                       labels = scales::percent) +
    scale_fill_manual(values = c("orange", "dodgerblue4")) +
    labs(x = "Country", y = "RVC Exports as Share of Total Exports", fill = "Term") +
    pretty_plot("right") +
    theme(axis.text.x = element_text(angle = 270, hjust = 0, vjust = 0.5))

ggsave("figures/GVC/EM_BS_GVC_CTRY_AFR_Values.pdf", width = 10, height = 4)

pdf("figures/GVC/EM_BS_GVC_CTRY_RVC_GEXP_Map.pdf", width = 8, height = 8)
print(tm_shape(join(africa_map, mutate(RVC_CTRY, Y = (I2E + E2R) * 100),
                   on = c("ISO_3DIGIT" = "country")), bbox = bbox) +
        tm_polygons(n = 10, style = "jenks",
                    col = "Y",
                    palette = "inferno",
                    title = "RVCs/GEXP (%)") +
        tm_map_layout())
dev.off()

EM_BS_AGG_AFR |>
  subset(order(NDAVAX + FVA, decreasing = TRUE)) |>
  mutate(country = qF(country, sort = FALSE)) |>
  select(country:FDC) |>
  pivot("country") |>
  ggplot(aes(x = country, y = value, fill = variable)) +
    geom_bar(stat = "identity", position = "stack") +
    scale_y_continuous(n.breaks = 7, expand = expansion(mult = c(0, 0.03)),
                       labels = scales::label_currency(suffix = "B", scale = 1e-3)) +
    scale_fill_manual(values = c("orange", "yellow2", "green2", "dodgerblue4", "dodgerblue")) +
    labs(x = "Country", y = "RVC Related Exports Contents", fill = "Term") +
    pretty_plot("right") +
    theme(axis.text.x = element_text(angle = 270, hjust = 0, vjust = 0.5))

ggsave("figures/GVC/EM_BS_KWW_EXT_CTRY_GVC_AFR.pdf", width = 10, height = 4)

qs_save(RVC_CTRY, "results/EM_RVCs_country.qs")
data.table::fwrite(RVC_CTRY, "results/EM_RVCs_country.csv")

########################################
# REC-Level RVCs
########################################

REC_AFR_FVAX <- leontief |>
  subset(source_country != using_country &
         source_country %in% am_countries$ISO3 &
         using_country %in% am_countries$ISO3) |>
  group_by(using_country, source_country) |>
  select(fvax) |> fsum() |>
  join(RECs |> select(ISO3, REC), on = c("source_country" = "ISO3")) |> rename(REC = source_REC) |>
  join(RECs |> select(ISO3, REC), on = c("using_country" = "ISO3")) |> rename(REC = using_REC) |>
  group_by(source_REC, using_REC) |>
  select(fvax) |> fsum()

GVC_REC_table <- EM_BS_AGG_AFR |>
  join(RECs |> select(ISO3, REC), on = c("country" = "ISO3")) |>
  group_by(REC) |>
  compute(E2R = NDAVAX + REF,
          I2E = psum(DDC, FVA, FDC)) |> fsum() %>% {
  rowbind(I2E = join(., REC_AFR_FVAX |>
    mutate(I2E_share = fsum(fvax, using_REC, TRA = "/")) |>
    pivot("using_REC", "I2E_share", "source_REC", how = "w"),
    on = c("REC" = "using_REC")
    ) |> transformv(-(1:3), `*`, I2E),
  E2R = join(., REC_AFR_FVAX |>
    mutate(E2R_share = fsum(fvax, source_REC, TRA = "/")) |>
    pivot("source_REC", "E2R_share", "using_REC", how = "w"),
    on = c("REC" = "source_REC")
  ) |> transformv(-(1:3), `*`, E2R), idcol = "measure")} |>
  transform(RVC = (I2E + E2R) / 2, E2R = NULL, I2E = NULL) |>
  group_by(REC) |> num_vars() |> fsum() |>
  colorder(REC, RVC)

GVC_REC_table |>
 xtable::xtable(digits = 1) |>
  print(include.r = FALSE, booktabs = TRUE)

pdf("figures/GVC/EM_EM_BS_RVC_BREC_MIG.pdf", width = 8, height = 8)
GVC_REC_table |>
  select(-RVC) |>
  pivot("REC") |>
  subset(REC != variable) |>
  migest::mig_chord()
dev.off()

qs_save(GVC_REC_table, "results/EM_RVCs_REC.qs")
data.table::fwrite(GVC_REC_table, "results/EM_RVCs_REC.csv")

########################################
# Country-Sector Level RVCs
########################################

EM_BS_AGG <- EM_BS$SEC |>
  subset(year > 2010 & from_region %in% am_countries$ISO3,
         sector_code, sector, from_region, vax, davax, ref, ddc, fva, fdc) |>
  group_by(sector_code, sector, from_region) |> fmean() |>
  transform(ndavax = vax - davax, davax = NULL, vax = NULL) |>
  colorder(country = from_region, sector_code, sector, ndavax) |>
  rename(toupper, cols = is.numeric)

RVC_CTRY_SEC <- EM_BS_AGG |>
  join(subset(GVC_SEC_AGG, africa, -africa),
       on = c("country", "sector_code" = "sector")) |>
  mutate(across(c(NDAVAX, REF), `*`, E2R_AFR),
         across(c(DDC, FVA, FDC), `*`, I2E_AFR),
         RVC = psum(NDAVAX, REF, DDC, FVA, FDC)) |>
  mutate(sector_code = nswitch(as.character(sector_code), "EGW", "SRV", "SMH", "SRV", "TRA", "SRV", "PTE", "SRV", "CON", "SRV", "FIB", "SRV", "PAO", "SRV",
                               default = as.character(sector_code)) |>
           factor(levels = c("AFF", "FBE", "PCM", "PSM", "MIN", "TEX", "WAP", "MPR", "ELM", "TEQ", "MAN", "SRV"))) |>
  collap(~ country + sector_code, fsum)

RVC_CTRY_SEC <- join(RVC_CTRY_SEC, RECs |> select(ISO3, REC), on = c("country" = "ISO3"))

RVC_CTRY_SEC |>
  subset(order(fsum(RVC, country, TRA = "fill"), decreasing = TRUE)) |>
  mutate(country = qF(paste0(country, " ($", signif(round(fsum(RVC, country, TRA = "fill"), 2), 3), "M)"),
                      sort = FALSE)) |>
  ggplot(aes(x = country, y = RVC, fill = sector_code)) +
    geom_bar(stat = "identity", position = "fill") +
    scale_y_continuous(n.breaks = 7, expand = c(0, 0),
                       labels = scales::percent) +
    scale_fill_manual(values = c(sub("#00FF2E", "#00CC66", rainbow(11)), "#000000")) +
    labs(x = "Country (Total RVC Exports)", y = "RVC Related Exports Contents", fill = "Sector") +
    pretty_plot("right") +
    theme(axis.text.x = element_text(angle = 270, hjust = 0, vjust = 0.5))

ggsave("figures/GVC/EM_BS_GVC_CTRY_GVC_AFR_SEC.pdf", width = 10, height = 4.5)

RVC_CTRY_SEC |>
  subset(order(fsum(RVC, country, TRA = "fill"), decreasing = TRUE)) |>
  transform(country = qF(country, sort = FALSE)) |>
  ggplot(aes(x = country, y = RVC, fill = sector_code)) +
  geom_bar(stat = "identity", position = "stack") +
  scale_y_continuous(n.breaks = 7, expand = expansion(mult = c(0, 0.03)),
                     labels = scales::label_currency(suffix = "B", scale = 1e-3)) +
  scale_fill_manual(values = c(sub("#00FF2E", "#00CC66", rainbow(11)), "#000000")) +
  labs(x = "Country", y = "RVC Related Exports Contents", fill = "Sector") +
  pretty_plot("right") +
  theme(axis.text.x = element_text(angle = 270, hjust = 0, vjust = 0.5))

ggsave("figures/GVC/EM_BS_GVC_CTRY_GVC_AFR_SEC_Values.pdf", width = 10, height = 4)

RVC_CTRY_SEC |>
  pivot("sector_code", "RVC", "REC", FUN = "sum", how = "w", sort = TRUE) |>
  (\(d) add_vars(d, Total = psum(num_vars(d))))() |> colorder(sector_code, Total) |>
  transformv(is.numeric, function(x) paste0(signif(round(x, 2), 4), " (",
                                            signif(proportions(x) * 100, 2), "%)")) |>
  xtable::xtable(digits = 1) |>
  print(include.r = FALSE, booktabs = TRUE)

hm_rec <- RVC_CTRY_SEC |>
  group_by(REC, sector_code, sector) |>
  select(RVC, NDAVAX) |> fsum() |>
  pivot(ids = "sector_code", values = "NDAVAX", names = "REC", how = "w") |>
  qM(1)
pheatmap::pheatmap(log10(hm_rec), cluster_rows = FALSE, cluster_cols = FALSE,
                   display_numbers = round(hm_rec, 2), legend = FALSE,
                   number_color = "black", border_color = NA,
                   color = colorRampPalette(RColorBrewer::brewer.pal(n = 7, name = "YlOrRd"))(100),
                   filename = "figures/GVC/EM_BS_GVC_REC_NDAVAX_AFR_SEC_Values.pdf",
                   width = 4.5, height = 4.5)

hm_ctry <- RVC_CTRY_SEC |>
  subset(country == fmode(country, REC, RVC, "fill")) |>
  pivot(ids = "sector_code", values = "NDAVAX", names = "country",
        how = "w", check.dups = TRUE) |>
  colorder(sector_code, EGY, COG, KEN, NGA, ETH, ZAF) |>
  qM(1)
pheatmap::pheatmap(log10(hm_ctry), cluster_rows = FALSE, cluster_cols = FALSE,
                   display_numbers = round(hm_ctry, 2), legend = FALSE,
                   number_color = "black", border_color = NA,
                   color = colorRampPalette(RColorBrewer::brewer.pal(n = 7, name = "YlOrRd"))(100),
                   filename = "figures/GVC/EM_BS_GVC_REClCTRY_NDAVAX_AFR_SEC_Values.pdf",
                   width = 4.5, height = 4.5)

africa_map %<>%
  join(RVC_CTRY_SEC %$% fmode(sector_code, country, RVC) %>% qDF("country") %>% rename(main_sector = "."),
       on = c("ISO_3DIGIT" = "country"))

pdf("figures/GVC/EM_BS_GVC_CTRY_Main_SEC_Map.pdf", width = 8, height = 8)
print(tm_shape(africa_map, bbox = bbox) +
        tm_polygons(col = "main_sector",
                    palette = c(sub("#00FF2E", "#00CC66", rainbow(11)), "#000000"),
                    title = "Main RVC Sector") +
        tm_map_layout())
dev.off()

africa_map %<>%
  join(RVC_CTRY_SEC %>% subset(sector_code %!in% c("PSM", "MIN")) %$% fmode(sector_code, country, RVC) %>%
         qDF("country") %>% rename(main_sector_nomin = "."),
       on = c("ISO_3DIGIT" = "country"), drop = "x")

pdf("figures/GVC/EM_BS_GVC_CTRY_Main_SEC_NoMIN_Map.pdf", width = 8, height = 8)
print(tm_shape(africa_map, bbox = bbox) +
        tm_polygons(col = "main_sector_nomin",
                    palette = c(sub("#00FF2E", "#00CC66", rainbow(11)), "#000000"),
                    title = "Main RVC Sector") +
        tm_map_layout())
dev.off()

RVC_CTRY_SEC %<>% join(GEXP) %>% mutate(RVC_EXP = RVC / fvax * 100)

for (sec in c("AFF", "FBE", "PCM", "PSM", "MIN", "SRV")) {
  pdf(sprintf("figures/GVC/EM_BS_GVC_CTRY_%s_RVC_Map.pdf", sec), width = 8, height = 8)
  print(tm_shape(join(africa_map,
                      subset(RVC_CTRY_SEC, sector_code == sec) |> fselect(country, RVC),
                      on = c("ISO_3DIGIT" = "country")), bbox = bbox) +
          tm_polygons(n = 10, style = "jenks",
                      col = "RVC",
                      palette = "inferno",
                      title = sprintf("%s RVC ($M)", sec)) +
          tm_map_layout())
  dev.off()
}

qs_save(RVC_CTRY_SEC, "results/EM_RVCs_country_sector.qs")
data.table::fwrite(RVC_CTRY_SEC, "results/EM_RVCs_country_sector.csv")

########################################
# Bilateral-Sector Level RVCs
########################################

I2E_AFR <- leontief |>
  subset(source_country != using_country & using_country %in% am_countries$ISO3) |>
  mutate(I2E_AFR = replace_na(fsum(fvax, list(using_country, using_industry), TRA = "/"))) |>
  subset(source_country %in% am_countries$ISO3) |>
  rename(fvax = I2E) |> rm_stub("using_") |> rename(sub, pat = "source", rep = "part")

E2R_AFR <- leontief |>
  subset(source_country != using_country & source_country %in% am_countries$ISO3) |>
  mutate(E2R_AFR = replace_na(fsum(fvax, list(source_country, source_industry), TRA = "/"))) |>
  subset(using_country %in% am_countries$ISO3) |>
  rename(fvax = E2R) |> rm_stub("source_") |> rename(sub, pat = "using", rep = "part")

GVC_SEC <- join(I2E_AFR, E2R_AFR) |> rename(sub, pat = "industry", rep = "sector")
rm(I2E_AFR, E2R_AFR)

RVC_BIL_SEC <- EM_BS_AGG |>
  join(GVC_SEC, on = c("country", "sector_code" = "sector"), how = "right") |>
  mutate(across(c(NDAVAX, REF), `*`, E2R_AFR),
         across(c(DDC, FVA, FDC), `*`, I2E_AFR),
         GVC = psum(NDAVAX, REF, DDC, FVA, FDC)) |>
  transformv(c(sector_code, part_sector), function(x) {
      nswitch(as.character(x), "EGW", "SRV", "SMH", "SRV", "TRA", "SRV", "PTE", "SRV", "CON", "SRV", "FIB", "SRV", "PAO", "SRV",
              default = as.character(x)) |>
      factor(levels = c("AFF", "FBE", "PCM", "PSM", "MIN", "TEX", "WAP", "MPR", "ELM", "TEQ", "MAN", "SRV"))
  }) |>
  collap(~ country + sector_code + part_country + part_sector, fsum)

RVC_BIL_AVG <- list(Overall = RVC_BIL_SEC |>
                      group_by(from = country, to = part_country) |>
                      num_vars() |> fsum(),
                    Manufacturing = RVC_BIL_SEC |>
                      subset(sector_code %in% MAN) |>
                      group_by(from = country, to = part_country) |>
                      num_vars() |> fsum())
qs_save(RVC_BIL_AVG, "results/EM_RVCs_bilateral_average.qs")
data.table::fwrite(RVC_BIL_AVG$Overall, "results/EM_RVCs_bilateral_overall.csv")
data.table::fwrite(RVC_BIL_AVG$Manufacturing, "results/EM_RVCs_bilateral_manufacturing.csv")

for (sec in c("AFF", "FBE", "PCM", "PSM", "MIN", "SRV")) {

trade_data <- RVC_BIL_SEC[sector_code %!in% c("PSM", "MIN", "SRV"), .(value = sum(GVC)),
                   by = .(from = country, to = part_country)]

outflows <- aggregate(trade_data$value, by = list(trade_data$from), FUN = sum)

trade_data %<>% subset(from != "ESH" & to != "ESH")
trade_data %<>% roworder(-value) %>% ss(1:50)

g <- graph_from_data_frame(trade_data, directed = TRUE)
E(g)$weight <- trade_data$value
vertex_sizes <- setNames(outflows$x, outflows$Group.1)
V(g)$size <- sapply(V(g)$name, function(x) vertex_sizes[x])
layout <- layout_with_fr(g, weights = E(g)$weight, niter = 10000)

pdf(sprintf("figures/GVC/EM_BS_GVC_CTRY_%s_RVC_Network.pdf", sec), width = 8, height = 8)
plot(g,
     vertex.shape = "circle",
     edge.arrow.mode = "-",
     edge.width = E(g)$weight^0.9 / 15,
     edge.color = "gray85",
     vertex.color = "lightblue",
     vertex.frame.color = NA,
     vertex.size = V(g)$size^0.4 + 5,
     vertex.label = V(g)$name,
     vertex.label.font = 6,
     vertex.label.family = "sans",
     vertex.label.color = "gray20",
     vertex.label.cex = .7,
     layout = layout)
dev.off()
}
