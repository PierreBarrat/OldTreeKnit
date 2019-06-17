"""
1. Resolve trees
2. Find MCCs
3. Infer common subtrees for MCCs using joint sequences
"""
function prunetrees_mut(segtrees, jointmsa; verbose = true)

	## Resolving, finding MCCs, and adjusting branch length to that of the joint tree
	# resolving
	_resolve_trees!(segtrees);
	# MCCs
	MCC = maximal_coherent_clades(collect(values(segtrees)))
	println("\n### MCCs ###\n")
	println("Found $(length(MCC)) MCCs of average size $(mean([length(x) for x in MCC]))")
	# Adjusting branch length in MCCs
	_adjust_branchlength!(segtrees, jointmsa, MCC)

	## Computing ancestral states
	crossmapping(segtrees)

	## Counting mutations
	map(s->fasta2tree!(segtrees[s], "CrossMapping/ancestral_tree_$(s)_aln_$(s)/ancestral_sequences.fasta"), segments)
	segmd_ref = Dict(s=>make_mutdict!(segtrees[s]) for s in segments)
	crossmuts = compute_crossmuts(segtrees, MCC, segmd_ref)

	## Finding suspicious MCCs
	fmcc, tofilter, confidence = find_suspicious_mccs(crossmuts, segtrees)
	iroot = findall(x->x==root_strain, tofilter)
	for i in iroot
		splice!(tofilter, i)
		splice!(confidence, i)
	end
	return tofilter, fmcc, confidence
end



"""
	_adjust_branchlength(segtrees, jointmsa, MCC)
"""
function _adjust_branchlength!(segtrees, jointmsa, MCC)
	for (s,t) in segtrees
		segtrees[s] = _adjust_branchlength(t, jointMSA, MCC)
	end
end

"""
	_adjust_branchlength(tree::Tree, jointmsa, MCC)

Copy `tree`. For all `m` in MCC: 
1. Prune MRCA of `m` from `tree`, giving `sub`
2. Scale branches of `sub` by calling Interfacing.scalebranches
3. Regraft `sub` at the right position
"""
function _adjust_branchlength(tree::Tree, jointmsa, MCC)
	t = deepcopy(tree)
	for m in MCC
		sub, r = prunesubtree!(t, m)
		sub = Interfacing.scalebranches(sub, jointmsa)
		graftnode!(r, sub)
	end
	return t
end


"""
"""
function crossmapping(segtrees)
	mkpath("CrossMapping")
	for (s,t) in segtrees
		write_newick("CrossMapping/tree_$(s)_adjusted.nwk", t)
	end
	map(k->run(`cp msas/aligned_simple_h3n2_$(k).fasta CrossMapping`), collect(keys(segtrees)))

	for s1 in segments
		for s2 in segments
			Interfacing.run_treetime(verbose=false, aln="CrossMapping/aligned_simple_h3n2_$(s1).fasta", tree="CrossMapping/tree_$(s2)_adjusted.nwk", out="CrossMapping/ancestral_tree_$(s2)_aln_$(s1)")
		end
	end
end

"""
Construct a dictionary of the form `"mcc label"=>CrossMutations`. 
Expects the directory CrossMapping to exist, containing ancestral sequences for all combinations of segments and trees. 
"""
function compute_crossmuts(segtrees, MCC, segmd_ref)
	# Building a [tree, aln] dictionary of mutations
	crossmuts_all = Dict()
	for a in keys(segtrees)
	    for t in keys(segtrees)
	        crossmuts_all[t,a] = parse_nexus("CrossMapping/ancestral_tree_$(t)_aln_$(a)/annotated_tree.nexus")
	    end
	end

	# Inverting it to have a "per MCC" dictionary of mutations
	crossmuts_mccs = Dict()
	for m in MCC
	    lab = lca([segtrees[segments[1]].lnodes[x] for x in m]).label
	    cm = CrossMutations()
	    for a in keys(segtrees)
	        for t in keys(segtrees)
	            cm.crossmut[t,a] = crossmuts_all[t,a][lab]
	            cm.suspicious[t,a] = 0
	            for mut in cm.crossmut[t,a]
	                if get(segmd_ref[a][1],mut,0)==0 && mut[2]!=5 && mut[3]!=5
	                    cm.suspicious[t,a] += 1
	                end
	            end
	        end
	    end
	    crossmuts_mccs[lab] = cm
	end	
	return crossmuts_mccs
end


"""
"""
function find_suspicious_mccs(crossmuts, segtrees)
	fmcc = []
	tofilter = Array{Any,2}(undef, 0, 2)
	confidence = []
	for (l,cm) in crossmuts # loop on mccs
	    if sum(values(cm.suspicious))>0
	        push!(fmcc, node_leavesclade_labels(segtrees[segments[1]].lnodes[l]))
	        # push!(tofilter, [x.label for x in node_leavesclade(segtrees[segments[1]].lnodes[l])]...)
	        strains = node_leavesclade_labels(segtrees[segments[1]].lnodes[l])
	        tofilter = [tofilter ; cat(strains, repeat([mcc_idx()], length(strains)), dims=2)]
        	push!(confidence, repeat([sum(collect(values(cm.suspicious)))], length(node_leavesclade(segtrees[segments[1]].lnodes[l])))...)
	    end
	end
	return fmcc, tofilter, confidence
end