#########################################
## Import and Aggregate EMERGING
#########################################

library(fastverse)
set_collapse(sort = FALSE, na.rm = FALSE, nthreads = 4)
fastverse_extend(rhdf5, readxl, qs2, install = TRUE) # BiocManager::install("rhdf5")
setwd("~/Documents/Data/EMERGING")

# Country and Sector Classification
EM_CTRY <- read_xlsx("EMERGING_Country.xlsx")
EM_SEC <- read_xlsx("EMERGING_Sector_V2.xlsx")

# Non-Country Entries
# EM_CTRY |> subset(ISO3 %!in% africamonitor::am_countries_wld$ISO3) |> View()

# Factor grouping object: aggregating to broad sectors
g <- finteraction(expand.grid(EM_SEC$Broad_Sector_Code, EM_CTRY$ISO3)[2:1])
g_fd <- finteraction(rep(EM_CTRY$ISO3, each = 3))

# Now Aggreagting
# h5ls("V2/EMERGING_V2_2015_m.mat") |> tail(10)

files <- list.files("V2", pattern = "_m.mat$", full.names = TRUE)

EM_DATA_Agg <- lapply(files, function(f) {
  data <- h5read(f, "/")
  list(
   X = drop(data$X) |> fsum(g),
   FD = data$f |> fsum(g) |> t() |> fsum(g_fd) |> t(),
   VA = drop(data$va) |> fsum(g),
   T = data$z |> fsum(g) |> t() |> fsum(g) |> t()
  )
}) |> set_names(substr(basename(files), 13, 16))
 
# Saving
list(DATA = EM_DATA_Agg,
     Regions = EM_CTRY |> fselect(ISO3, Country) |> funique(),
     Sectors = EM_SEC |> gvr("Broad") |> funique()) |>
  qs_save("EMERGING_Broad_Sectors.qs2")




#############################################
# Aggregate to country level (separate files)
#############################################

if(FALSE) {
  
g <- finteraction(expand.grid(EM_SEC$Code_HS2002, 
                              iif(EM_CTRY$ISO3 %in% africamonitor::am_countries_wld$ISO3, EM_CTRY$ISO3, "ROW"))[2:1])
g_fd <- finteraction(rep(iif(EM_CTRY$ISO3 %in% africamonitor::am_countries_wld$ISO3, EM_CTRY$ISO3, "ROW"), each = 3))

files <- list.files(pattern = "\\.mat$")

# Most memory efficient way of coding it
gc()
for (f in files) {
  print(f)
  data = h5read(f, "/"); gc()
  X = drop(data$X) |> fsum(g)
  FD = data$f |> fsum(g) |> t() |> fsum(g_fd) |> t()
  VA = drop(data$va) |> fsum(g)
  z = data$z
  rm(data); gc()
  T = fsum(z, g) 
  rm(z); gc()
  T = t(T); gc()
  T = fsum(T, g); gc() 
  T = t(T); gc()
  res = list(X = X, FD = FD, VA = VA, T = T)
  list(DATA = res,
       Regions = EM_CTRY |> fselect(ISO3, Country) |> rowbind(list(ISO3 = "ROW", Country = "Rest of World")) |>
         fsubset(ckmatch(levels(g_fd), ISO3)),
       Sectors = EM_SEC |> fselect(-Code) |> funique()) |> 
    qsave(sprintf("EMERGING_Countries_%s.qs", substr(f, 13, 16)))
  rm(res, X, FD, VA, T); gc(); gc()
}

}
