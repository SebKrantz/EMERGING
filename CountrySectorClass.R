#########################################
## Country and Sector Classification
## EMERGING MRIO v2 – https://zenodo.org/records/19461860
#########################################

library(fastverse)
fastverse_extend(rhdf5, openxlsx, install = TRUE)

files <- list.files("V2", pattern = "_m.mat$", full.names = TRUE)

# MATLAB HDF5 cell arrays of strings are stored as object reference datasets.
# rhdf5 returns them as H5Ref objects; dereference each to a uint16 array and
# decode with intToUtf8() (MATLAB stores chars as UTF-16LE integers).
read_ref_strings <- function(fid, path) {
  ds   <- H5Dopen(fid, path)
  refs <- H5Dread(ds)
  H5Dclose(ds)
  n <- length(refs@val) / 8L
  vapply(seq_len(n), function(i) {
    did <- H5Rdereference(refs[i], fid)
    val <- H5Dread(did)
    H5Dclose(did)
    intToUtf8(as.integer(val))
  }, character(1))
}

fid          <- H5Fopen(files[1])
country_list <- read_ref_strings(fid, "country_list")
sector_list  <- read_ref_strings(fid, "sector_list")
final_list   <- read_ref_strings(fid, "final_list")
H5Fclose(fid)

countries    <- data.frame(Index = seq_along(country_list), Country      = country_list)
sectors      <- data.frame(Index = seq_along(sector_list),  Sector       = sector_list)
final_demand <- data.frame(Index = seq_along(final_list),   Final_Demand = final_list)

# --- Export ---------------------------------------------------------------
wb <- createWorkbook()

header_style <- createStyle(fontColour = "#FFFFFF", fgFill = "#2F5496",
                             halign = "left", textDecoration = "bold",
                             border = "Bottom", borderColour = "#1F3864")

write_sheet <- function(wb, sheet, df) {
  addWorksheet(wb, sheet)
  writeData(wb, sheet, df, headerStyle = header_style)
  setColWidths(wb, sheet, cols = seq_along(df), widths = "auto")
  freezePane(wb, sheet, firstRow = TRUE)
}

write_sheet(wb, "Countries",   countries)
write_sheet(wb, "Sectors",     sectors)
write_sheet(wb, "FinalDemand", final_demand)

saveWorkbook(wb, "EMERGING_Classification.xlsx", overwrite = TRUE)
message("Exported EMERGING_Classification.xlsx  (",
        nrow(countries), " countries / ", nrow(sectors), " sectors / ",
        nrow(final_demand), " final-demand categories)")
