```@meta
CurrentModule = TreeKnit
DocTestSetup  = quote
    using TreeTools
end	
```

# Functions

```@index
Pages = ["functions.md"]
```

## Computing Maximal Compatible Clades (MCCs) for a set of trees
### Main functions 
```@docs
computeMCCs
computeMCCs!
```

### For pairs of trees only
```@docs
naive_mccs
TreeKnit.runopt
```

## Resolving trees
### Using topology
```@docs
resolve!(::TreeTools.Tree, ::TreeTools.Tree)
```