# PowerSystemsTestData

This repository contains several data files used to test the modeling packages in [SIIP](https://github.com/NREL-SIIP/).

## Fuel Type Mapping

When using CSV data inputs with the `3_Zones_simulation.ipynb` notebook or similar workflows, you need to provide a `FuelMapping.csv` file that maps fuel type names from your data to PowerSystems.jl `ThermalFuels` enum values.

### Example FuelMapping.csv

See `FuelMapping_example.csv` for a sample mapping file. The format is:

```csv
Key,Value
coal,COAL
ng,NATURAL_GAS
nuclear,NUCLEAR
```

The `Key` column should match the fuel types in your thermal generator data, and the `Value` column should be valid `ThermalFuels` enum values from PowerSystems.jl.

### Available ThermalFuels Values

Valid values include:
- COAL, ANTHRACITE_COAL, BITUMINOUS_COAL, LIGNITE_COAL, SUBBITUMINOUS_COAL
- NATURAL_GAS, OTHER_GAS
- DISTILLATE_FUEL_OIL, RESIDUAL_FUEL_OIL, PETROLEUM_COKE
- NUCLEAR
- OTHER_BIOMASS_SOLIDS, OTHER_BIOMASS_LIQUIDS, WOOD_WASTE_SOLIDS, BLACK_LIQUOR
- GEOTHERMAL
- OTHER

For a complete list, see the [PowerSystems.jl definitions](https://github.com/NREL-Sienna/PowerSystems.jl/blob/main/src/definitions.jl). 
