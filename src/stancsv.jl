using DelimitedFiles: readdlm

"""
    FlexiChains.from_stan_csv(base_path::String, num_chains::Int)

TODO
"""
function from_stan_csv(base_path::String, num_chains::Int)
    if num_chains <= 0
        throw(ArgumentError("num_chains must be more than 1"))
    end

    # Parse sampling settings from the first CSV. This is pretty ugly, but well, it doesn't
    # have to be pretty.
    first_csv_path = "$(base_path)_chain_1.csv"
    if !isfile(first_csv_path)
        throw(ArgumentError("expected CSV file for chain 1 not found at path: $first_csv_path. Have you run the sampling process?"))
    end
    nsamples = nothing
    thin = nothing
    save_warmup = nothing
    nwarmup = nothing
    open(first_csv_path) do io
        for line in eachline(io)
            startswith(line, '#') || break
            m = match(r"^#\s*num_samples\s*=\s*(\d+)", line)
            m !== nothing && (nsamples = parse(Int, m.captures[1]))
            m = match(r"^#\s*thin\s*=\s*(\d+)", line)
            m !== nothing && (thin = parse(Int, m.captures[1]))
            m = match(r"^#\s*save_warmup\s*=\s*(true|false)", line)
            m !== nothing && (save_warmup = m.captures[1] == "true")
            m = match(r"^#\s*num_warmup\s*=\s*(\d+)", line)
            m !== nothing && (nwarmup = parse(Int, m.captures[1]))
        end
    end
    if any(x -> x === nothing, [nsamples, thin, save_warmup, nwarmup])
        throw(ArgumentError("failed to parse sampling settings from CSV metadata comments; please check the CSV file at $first_csv_path and ensure it contains the expected metadata comments for num_samples, thin, save_warmup, and num_warmup"))
    end

    niters = save_warmup ? nsamples + nwarmup : nsamples
    iter_indices = if save_warmup
        warmup_iters = 1:nwarmup
        sample_iters = range(nwarmup + 1, step = thin, stop = nwarmup + nsamples)
        vcat(warmup_iters, sample_iters)
    else
        range(nwarmup + 1, step = thin, stop = nwarmup + nsamples)
    end

    # Read chains from CSV files into Dict(Symbol => Vector{Float64})
    header = nothing
    data = []
    for i in 1:num_chains
        csv_path = "$(base_path)_chain_$i.csv"
        if !isfile(csv_path)
            throw(ArgumentError("expected CSV file for chain $i not found at path: $csv_path. Have you run the sampling process?"))
        end
        # data_i is niters x nparams
        data_i, header = readdlm(csv_path, ','; header = true, comments = true)
        push!(data, data_i)
    end
    data = stack(data) # niters x nparams x nchains

    data_dict = OrderedDict{ParameterOrExtra{<:Symbol}, Matrix{Float64}}()
    # Sort out parameters vs extras based on header names
    for (i, colname) in enumerate(header)
        if endswith(colname, "__")
            data_dict[Extra(Symbol(colname[1:(end - 2)]))] = data[:, i, :]
        else
            data_dict[Parameter(Symbol(colname))] = data[:, i, :]
        end
    end
    return FlexiChain{Symbol}(niters, num_chains, data_dict; iter_indices = iter_indices)
end
