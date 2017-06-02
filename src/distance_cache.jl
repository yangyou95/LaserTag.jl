immutable ClearDistances
    cardinal::SVector{4, Int}
    diagonal::SVector{4, Int}
end

function find_distances(f::Floor, obstacles::Set{Coord}, s::LTState)
    card = MVector{4, Int}()
    diag = MVector{4, Int}()
    for i in 1:4
        d = 1
        while !opaque(f, obstacles, s, s.robot+d*CARDINALS[i])
            d += 1
        end
        card[i] = d-1
    end
    for i in 1:4
        d = 1
        while !opaque(f, obstacles, s, s.robot+d*DIAGONALS[i])
            d += 1
        end
        diag[i] = d-1
    end
    return ClearDistances(card, diag)
end

type LTDistanceCache
    floor::Floor
    distances::Vector{ClearDistances}
end

function LTDistanceCache(f::Floor, obstacles::Set{Coord})
    dists = Array(ClearDistances, n_pos(f)^2)
    visited = falses(n_pos(f)^2)
    for i in 1:f.n_cols, j in 1:f.n_rows, k in 1:f.n_cols, l in 1:f.n_rows
        s = LTState(Coord(i,j), Coord(k,l), false)
        ii = state_index(f, s)
        visited[ii] = true
        dists[ii] = find_distances(f, obstacles, s)
    end
    @assert all(visited)
    push!(dists, ClearDistances(zeros(4), zeros(4)))
    return LTDistanceCache(f, dists)
end

Base.getindex(c::LTDistanceCache, s::LTState) = c.distances[state_index(c.floor, s)]

function n_clear_cells(d::ClearDistances, dir::Int)
    if i <= 4
        return d.cardinal[dir]
    else
        return d.diagonal[dir-4]
    end
end

immutable ReadingCDF
    cardcdf::Vector{Float64}
    diagcdf::Vector{Float64}
end

# reading CDF
function ReadingCDF(f::Floor,
                    std::Float64,
                    maxread::Int=ceil(Int, max_diag(f)+4*std))
    maxclear = max(f.n_rows, f.n_cols) - 1
    cardcdf = Array(Float64, maxclear + maxread + 1)

    for noise in -maxclear:maxread
        cardcdf[noise+maxclear+1] = (1+erf((noise+0.5-c)/(std*sqrt(2))))/2
    end

    diagcdf = Array(Float64, maxclear + maxread + 1)
    for noise in -maxclear:maxread
        diagcdf[noise+maxclear+1] = (1+erf((r+0.5-c*sqrt(2))/(std*sqrt(2))))/2
    end

    return ReadingCDF(cardcdf, diagcdf)
end

function cdf(c::ReadingCDF, dir::Int, clear::Int, reading::Int)
    noise = reading - clear
    maxclear = max(f.n_rows, f.n_cols) - 1
    if dir <= 4 # cardinal
        if noise + maxclear >= length(c.cardcdf)
            return 1.0
        else
            return c.cardcdf[noise + maxclear + 1]
        end
    else # diagonal
        if noise + maxclear >= length(c.diagcdf)
            return 1.0
        else
            return c.diagcdf[noise + maxclear + 1]
        end
    end
end
