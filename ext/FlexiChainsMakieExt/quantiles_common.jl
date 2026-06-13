# Shared helpers for the Betancourt quantile plots.

function _resolve_base_color(color)
    return if color isa Makie.Cycled
        Makie.current_default_theme()[:palette][:color][][color.i]
    else
        Makie.to_color(color)
    end
end

# Nested-band alpha ramp: inner band (i = n_bands) most opaque.
_band_alpha(i, n_bands) = 0.2 + 0.7 * i / n_bands
