library(fastverse)
fastverse_extend(qs2)


EM <- qs_read("EMERGING_Broad_Sectors.qs2") 

ICIO_path <- "ICIO_CSV/EMERGING_Broad_Sectors"
dir.create(ICIO_path, recursive = TRUE)
list.files(ICIO_path)
# unlink(ICIO_path, recursive = TRUE)


# Write countrylist
EM$Regions |> get_vars("ISO3") |> 
  fwrite(paste(ICIO_path, "EM_countrylist.csv", sep = "/"), col.names = FALSE)

# Now loop across datasets
years <- names(EM$DATA)

for (y in years) {
  cat(y, fill = TRUE)
  x <- EM$DATA[[y]]
  qDF(setRownames(cbind(x$T, x$FD))) |> 
    fwrite(paste0(ICIO_path, "/EM_", y, ".csv"), col.names = FALSE)
}

#######################
# Template Data
#######################

# Create Template Data Frame: Not really needed !
GVC_grid <- expand.grid(from_sector = EM$Sectors$Broad_Sector_Code,
                        from_region = EM$Regions$ISO3,
                        to_sector = EM$Sectors$Broad_Sector_Code,
                        to_region = EM$Regions$ISO3) |> 
            colorder(from_region, from_sector, to_region, to_sector) |> 
            fsubset(from_region %!=% to_region)

GVC_grid |> fwrite(paste(ICIO_path, "GVC_grid.csv", sep = "/"))

