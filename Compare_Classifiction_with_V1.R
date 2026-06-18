library(fastverse)
fastverse_extend(readxl)

# Countries: Match
countries_v2 <- read_excel("EMERGING_Classification.xlsx", sheet = "Countries")
countries_v1 <- read_excel("EMERGING_Country.xlsx")
m <- match(countries_v1$ISO3, countries_v2$Country)
is.unsorted(na_rm(m))
countries_v1$ISO3[is.na(m)]
countries_v2$Country[is.na(m)]

# Sectors: V2 only missing 27: Mineral fuels, oils, distillation products, etc.
sectors_v2 <- read_excel("EMERGING_Classification.xlsx", sheet = "Sectors")
sectors_v1 <- read_excel("EMERGING_Sector.xlsx")
sectors_v1[27, .c(Code_HS2002, Sector)]
# View(cbind(sectors_v2, sectors_v1[-27, .c(Code_HS2002, Sector)]))

sectors_v1[-27, ] |> 
  writexl::write_xlsx("EMERGING_Sector_V2.xlsx")
