# bitboards for sliding pieces attacks 
# magic because using a "magic number" 
using Random

function trace_ray(sq::Int, dir::Int, occupied::Bitboard)::Bitboard 
    attacks = EMPTY_BB
    current_sq = sq
    current_rank = rank_of(sq)
    current_file = file_of(sq)

    while true # move along ray
        next_sq = current_sq + dir
        if !is_valid_square(next_sq)
            break
        end

        next_rank = rank_of(next_sq)
        next_file = file_of(next_sq)
        rank_diff = abs(next_rank - current_rank)
        file_diff = abs(next_file - current_file)

        if rank_diff > 1 || file_diff > 1
            # wrapped around board
            break
        end

        attacks = set_bit(attacks, next_sq)

        if test_bit(occupied, next_sq)
            break
        end

        current_sq = next_sq
        current_rank = next_rank
        current_file = next_file
    end
    return attacks
end

function rook_attacks_slow(sq::Int, occupied::Bitboard)::Bitboard
    return trace_ray(sq, NORTH, occupied) |
           trace_ray(sq, SOUTH, occupied) | 
           trace_ray(sq, WEST, occupied) | 
           trace_ray(sq, EAST, occupied)
end

function bishop_attacks_slow(sq::Int, occupied::Bitboard)::Bitboard
    return trace_ray(sq, NORTH_EAST, occupied) |
           trace_ray(sq, NORTH_WEST, occupied) | 
           trace_ray(sq, SOUTH_EAST, occupied) | 
           trace_ray(sq, SOUTH_WEST, occupied)
end

# lance is only south or north
function lance_attacks_slow(sq::Int, occupied::Bitboard, color::Color)::Bitboard 
    dir = (color == BLACK) ? NORTH : SOUTH
    return trace_ray(sq, dir, occupied)
end
# mask of possible blockers, edges arent blockers because you can't go past an edge/ not blocking anything beyond itself
function compute_rook_mask(sq::Int)::Bitboard
    mask = EMPTY_BB
    sq_rank = rank_of(sq)
    sq_file = file_of(sq)
    # north ray 
    for r in (sq_rank - 1):-1:2
        mask = set_bit(mask, square_index(r, sq_file))
    end
    # south ray
    for r in (sq_rank + 1):(BOARD_SIZE - 1)
        mask = set_bit(mask, square_index(r, sq_file))
    end
    # west ray
    for f in (sq_file - 1):-1:2
        mask = set_bit(mask, square_index(sq_rank, f))
    end
    # east ray
    for f in (sq_file + 1):(BOARD_SIZE - 1)
        mask = set_bit(mask, square_index(sq_rank, f))
    end
    return mask
end

function compute_bishop_mask(sq::Int)::Bitboard 
    mask = EMPTY_BB
    sq_rank = rank_of(sq)
    sq_file = file_of(sq)
    # diagonal
    for (dr, df) in [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        r, f = sq_rank + dr, sq_file + df
        while (2 <= r <= BOARD_SIZE - 1) && (2 <= f <= BOARD_SIZE - 1)
            mask = set_bit(mask, square_index(r, f))
            r += dr
            f += df
        end
    end
    return mask
end

function compute_lance_mask(sq::Int, color::Color)::Bitboard 
    mask = EMPTY_BB
    sq_rank = rank_of(sq)
    sq_file = file_of(sq)
    # north or south ray
    if color == BLACK 
        # north ray
        for r in (sq_rank - 1):-1:2
            mask = set_bit(mask, square_index(r, sq_file))
        end
    else
        # south ray
        for r in (sq_rank + 1):(BOARD_SIZE - 1)
            mask = set_bit(mask, square_index(r, sq_file))
        end
    end
    return mask
end

function enumerate_occupancies(mask::Bitboard)::Vector{Bitboard}
    n_bits = popcount(mask)
    n_subsets = 1 << n_bits
    occupancies = Vector{Bitboard}(undef, n_subsets)
    subset = EMPTY_BB

    for i in 1:n_subsets
        occupancies[i] = subset
        subset = (subset - mask) & mask
    end
    return occupancies
end

function find_magic(sq::Int, mask::Bitboard, is_rook::Bool; max_attempts::Int = 10_000_000)::Tuple{Bitboard, Int, Vector{Bitboard}}
    n_bits = popcount(mask)
    table_size = 1 << n_bits

    occupancies = enumerate_occupancies(mask)
    attacks = Vector{Bitboard}(undef, length(occupancies))

    for (i, occ) in enumerate(occupancies)
        if is_rook
            attacks[i] = rook_attacks_slow(sq, occ)
        else
            attacks[i] = bishop_attacks_slow(sq, occ)
        end
    end

    shift = 8 * sizeof(Bitboard) - n_bits

    for attempt in 1:max_attempts
        magic = rand(Bitboard) & rand(Bitboard) & rand(Bitboard)
        if magic == 0
            continue
        end

        table = fill(FULL_BB, table_size)
        valid = true
        for (i, occ) in enumerate(occupancies)
            index = Int(((occ * magic) >> shift) + 1)
            if index < 1 || index > table_size
                valid = false
                break
            end
            if table[index] == FULL_BB
                table[index] = attacks[i]
            elseif table[index] != attacks[i]
                valid = false
                break
            end
        end
        if valid
            return (magic, shift, table)
        end
    end
    error("Failed to find magic number for square $sq after $max_attempts attempts.")
end

function find_lance_magic(sq::Int, mask::Bitboard, color::Color; max_attempts::Int = 10_000_000)::Tuple{Bitboard, Int, Vector{Bitboard}}
    n_bits = popcount(mask)
    if n_bits == 0
        attacks = lance_attacks_slow(sq, EMPTY_BB, color)
        return (Bitboard(0), 0, [attacks])
    end

    table_size = 1 << n_bits
    occupancies = enumerate_occupancies(mask)
    attacks = Vector{Bitboard}(undef, length(occupancies))

    for (i, occ) in enumerate(occupancies)
        attacks[i] = lance_attacks_slow(sq, occ, color)
    end

    shift = 8 * sizeof(Bitboard) - n_bits

    for attempt in 1:max_attempts
        magic = rand(Bitboard) & rand(Bitboard) & rand(Bitboard)
        
        if magic == 0
            continue
        end
        
        table = fill(FULL_BB, table_size)
        valid = true
        
        for (i, occ) in enumerate(occupancies)
            index = Int(((occ * magic) >> shift) + 1)
            
            if index < 1 || index > table_size
                valid = false
                break
            end
            
            if table[index] == FULL_BB
                table[index] = attacks[i]
            elseif table[index] != attacks[i]
                valid = false
                break
            end
        end
        
        if valid
            return (magic, shift, table)
        end
    end
    
    error("Failed to find lance magic for square $sq, color $color") 
end

mutable struct MagicEntry
    mask::Bitboard
    magic::Bitboard
    shift::Int
    attacks::Vector{Bitboard}
end

const ROOK_MAGICS = Vector{MagicEntry}(undef, NUM_SQUARES)
const BISHOP_MAGICS = Vector{MagicEntry}(undef, NUM_SQUARES)
const LANCE_MAGICS = Matrix{MagicEntry}(undef, 2, NUM_SQUARES) # color then squares
const MAGICS_INITIALIZED = Ref(false)

function init_rook_magics!()
    for sq in 1:NUM_SQUARES
        mask = compute_rook_mask(sq)
        magic, shift, table = find_magic(sq, mask, true)
        ROOK_MAGICS[sq] = MagicEntry(mask, magic, shift, table)
    end
end

function init_bishop_magics!()
    for sq in 1:NUM_SQUARES
        mask = compute_bishop_mask(sq)
        magic, shift, table = find_magic(sq, mask, false)
        BISHOP_MAGICS[sq] = MagicEntry(mask, magic, shift, table)
    end
end

function init_lance_magics!()
    for color in (BLACK, WHITE)
        for sq in 1:NUM_SQUARES
            mask = compute_lance_mask(sq, color)
            magic, shift, table = find_lance_magic(sq, mask, color)
            LANCE_MAGICS[Int(color), sq] = MagicEntry(mask, magic, shift, table)
        end
    end
end

function init_all_magics!()
    if MAGICS_INITIALIZED[]
        return
    end

    Random.seed!(42)

    init_rook_magics!()
    init_bishop_magics!()
    init_lance_magics!()

    MAGICS_INITIALIZED[] = true
    println("All magic tables initialized.")
end

# faster lookups during play
@inline function rook_attacks(sq::Int, occupied::Bitboard)::Bitboard
    entry = ROOK_MAGICS[sq]
    relevant_occ = occupied & entry.mask
    index = Int(((relevant_occ * entry.magic) >> entry.shift) + 1)
    return entry.attacks[index]    
end
@inline function bishop_attacks(sq::Int, occupied::Bitboard)::Bitboard
    entry = BISHOP_MAGICS[sq]
    relevant_occ = occupied & entry.mask
    index = Int(((relevant_occ * entry.magic) >> entry.shift) + 1)
    return entry.attacks[index]
end
@inline function lance_attacks(sq::Int, occupied::Bitboard, color::Color)::Bitboard
    entry = LANCE_MAGICS[Int(color), sq]
    if isempty(entry.attacks)
        return EMPTY_BB
    end

    relevant_occ = occupied & entry.mask
    if entry.mask == EMPTY_BB
        return entry.attacks[1]
    end

    index = Int(((relevant_occ * entry.magic) >> entry.shift) + 1)
    return entry.attacks[index]
end

@inline function horse_attacks(sq::Int, occupied::Bitboard)::Bitboard
    return bishop_attacks(sq, occupied) | horse_bonus_attacks(sq)
end
@inline function dragon_attacks(sq::Int, occupied::Bitboard)::Bitboard
    return rook_attacks(sq, occupied) | dragon_bonus_attacks(sq)
end

function get_sliding_attacks(sq::Int, pt::PieceType, occupied::Bitboard, color::Color)::Bitboard
    if pt == ROOK
        return rook_attacks(sq, occupied)
    elseif pt == BISHOP
        return bishop_attacks(sq, occupied)
    elseif pt == LANCE
        return lance_attacks(sq, occupied, color)
    elseif pt == PROMOTED_ROOK
        return dragon_attacks(sq, occupied)
    elseif pt == PROMOTED_BISHOP
        return horse_attacks(sq, occupied)
    else
        return EMPTY_BB
    end
end

function demo_sliding_attacks(sq::Int, piece::String, blockers::Bitboard = EMPTY_BB)
    if !MAGICS_INITIALIZED[]
        init_all_magics!()
    end
    
    println("\n$piece on square $sq (rank $(rank_of(sq)), file $(file_of(sq)))")
    
    print_bitboard(blockers, "Blockers:")
    
    attacks = if piece == "rook"
        rook_attacks(sq, blockers)
    elseif piece == "bishop"
        bishop_attacks(sq, blockers)
    elseif piece == "horse"
        horse_attacks(sq, blockers)
    elseif piece == "dragon"
        dragon_attacks(sq, blockers)
    elseif piece == "lance_black"
        lance_attacks(sq, blockers, BLACK)
    elseif piece == "lance_white"
        lance_attacks(sq, blockers, WHITE)
    else
        EMPTY_BB
    end
    
    print_bitboard(attacks, "Attacks:")
end

# demo_sliding_attacks(13, "rook", bitboard_from_squares(8, 14))