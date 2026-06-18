# GVC decompositions of the EMERGING ICIO tables — full Julia/ICIO.jl pipeline.
#
# Julia replacement for ICIO_decomp.do. Runs all three decompositions and writes the same
# three output files. Each yearly table is read and inverted ONCE, then all three
# decompositions are computed from it (the Stata .do reloads the table for every block).
#
#   Block 1  country, world / sink        (9 terms)  -> EM_GVC_KWW_BM19.csv
#   Block 2  exporter-sector, exp/source  (13 terms) -> EM_GVC_SEC_BM19.csv
#   Block 3  bilateral-sector, exp/source (13 terms) -> EM_GVC_BIL_SEC_BM19.csv
#
# Run:  julia /Users/sebastiankrantz/Documents/Data/EMERGING/decomposition/ICIO_decomp.jl

import Pkg
Pkg.activate("/Users/sebastiankrantz/Documents/Julia/ICIO.jl")   # the ICIO.jl package env
using ICIO, CSV, DataFrames

# ---- paths & metadata ----
base    = "/Users/sebastiankrantz/Documents/Data/EMERGING/ICIO_CSV/EMERGING_Broad_Sectors"
clist   = joinpath(base, "EM_countrylist.csv")
years   = (2015, 2018, 2021, 2023)
# EMERGING broad-sector codes, in table order (sector index 1..18)
SECTORS = ["AFF","FBE","PCM","PSM","TEX","WAP","MPR","ELM","TEQ","MAN",
           "EGW","MIN","SMH","TRA","PTE","CON","FIB","PAO"]

out_cty = joinpath(base, "EM_GVC_KWW_BM19.csv")      # country  (world/sink,    9 terms)
out_sec = joinpath(base, "EM_GVC_SEC_BM19.csv")      # sector   (exp/source,  13 terms)
out_bil = joinpath(base, "EM_GVC_BIL_SEC_BM19.csv")  # bilateral(exp/source,  13 terms)
foreach(p -> isfile(p) && rm(p), (out_cty, out_sec, out_bil))

# helper: append a year's DataFrame to a CSV (write header only on the first year)
function stream!(path, df, y, first)
    insertcols!(df, 1, :year => y)
    CSV.write(path, df; append = !first, writeheader = first)
    return nrow(df)
end

for (i, y) in enumerate(years)
    first = i == 1
    print("Year $y: loading…"); flush(stdout)
    t0 = time()
    m = read_icio_csv(joinpath(base, "EM_$(y).csv"), clist; sectors = SECTORS)

    print(" country…"); flush(stdout)
    nc = stream!(out_cty, decompose(m; level = :country, perspective = :world, approach = :sink), y, first)

    print(" sector…"); flush(stdout)
    ns = stream!(out_sec, decompose(m; level = :sector), y, first)

    print(" bilateral…"); flush(stdout)
    nb = stream!(out_bil, decompose(m; level = :bilateral), y, first)

    println("  [", round(time() - t0, digits = 1), "s]  rows: cty=$nc sec=$ns bil=$nb")
    m = nothing; GC.gc()
end

println("Done. Wrote:")
println("  ", out_cty)
println("  ", out_sec)
println("  ", out_bil)
