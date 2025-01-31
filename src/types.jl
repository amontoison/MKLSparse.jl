# MKL sparse types

@inline function mkl_valtype_specifier(::Type{Tv}) where Tv <: BlasFloat
    if Tv == Float32
        's'
    elseif Tv == Float64
        'd'
    elseif Tv == ComplexF32
        'c'
    elseif Tv == ComplexF64
        'z'
    else
        throw(ArgumentError(lazy"Unsupported sparse value type $Tv"))
    end
end

@inline function mkl_indextype_specifier(::Type{Ti}) where Ti <: Integer
    if Ti == Int32
        ""
    elseif Ti == Int64
        "_64"
    else
        throw(ArgumentError(lazy"Unsupported sparse index type $Ti"))
    end
end

mkl_storagetype_specifier(::Type{S}) where S <: AbstractSparseMatrix =
    throw(ArgumentError(lazy"Unsupported sparse matrix storage type $S"))

mkl_storagetype_specifier(::Type{<:SparseMatrixCSC}) = "csc"

# generates the name of the MKL call from the template:
# 'S' is replaced by a specifier of the sparse storage type S
# 'T' is replaced by a specifier of the value type Tv
# 'I' is replaced by a specifier of the index type Ti
# (e.g. for :mkl_sparse_T_create_SI template and SparseMatrixCSC{Float32, Int64}
#  the returned function name would be :mkl_sparse_s_create_csc_I64)
@inline Base.@assume_effects :foldable mkl_function_name(template::Symbol, S::Type, Tv::Type, Ti::Type) =
    Symbol(replace(String(template),
                   "T" => mkl_valtype_specifier(Tv),
                   "I" => mkl_indextype_specifier(Ti),
                   "S" => mkl_storagetype_specifier(S)))

matrix_descr(A::LowerTriangular)     = matrix_descr('T','L','N')
matrix_descr(A::UpperTriangular)     = matrix_descr('T','U','N')
matrix_descr(A::Diagonal)            = matrix_descr('D','F','N')
matrix_descr(A::UnitLowerTriangular) = matrix_descr('T','L','U')
matrix_descr(A::UnitUpperTriangular) = matrix_descr('T','U','U')
matrix_descr(A::Symmetric)           = matrix_descr('S', A.uplo, 'N')
matrix_descr(A::Hermitian)           = matrix_descr('H', A.uplo, 'N')
matrix_descr(A::SparseMatrixCSC)     = matrix_descr('G', 'F', 'N')
matrix_descr(A::Transpose)           = matrix_descr(A.parent)
matrix_descr(A::Adjoint)             = matrix_descr(A.parent)

# modify the specific fields of the descriptor
matrix_descr(descr::matrix_descr;
             type::sparse_matrix_type_t = descr.type,
             mode::sparse_fill_mode_t = descr.mode,
             diag::sparse_diag_type_t = descr.diag) =
    matrix_descr(type, mode, diag)

@inline function Base.convert(::Type{sparse_operation_t}, trans::Char)
    if trans == 'N'
        SPARSE_OPERATION_NON_TRANSPOSE
    elseif trans == 'T'
        SPARSE_OPERATION_TRANSPOSE
    elseif trans == 'C'
        SPARSE_OPERATION_CONJUGATE_TRANSPOSE
    else
        throw(ArgumentError(lazy"Unknown operation $trans"))
    end
end

# given matrix eltype and N/C/T opcode, return the operation for the adjoint matrix ([CT]/N/N)
@inline function dual_opcode(::Type{T}, trans::Char) where T <: Number
    if trans == 'N'
        return T <: Complex ? 'C' : 'T'
    elseif trans == 'T' || trans == 'C'
        return 'N'
    else
        throw(ArgumentError(lazy"Unknown operation $trans"))
    end
end

@inline Base.convert(::Type{sparse_operation_t}, ::Type{<:Transpose}) =
    SPARSE_OPERATION_TRANSPOSE

@inline Base.convert(::Type{sparse_operation_t}, ::Type{<:Adjoint}) =
    SPARSE_OPERATION_CONJUGATE_TRANSPOSE

@inline function Base.convert(::Type{sparse_matrix_type_t}, mattype::Char)
    if mattype == 'G'
        SPARSE_MATRIX_TYPE_GENERAL
    elseif mattype == 'S'
        SPARSE_MATRIX_TYPE_SYMMETRIC
    elseif mattype == 'H'
        SPARSE_MATRIX_TYPE_HERMITIAN
    elseif mattype == 'T'
        SPARSE_MATRIX_TYPE_TRIANGULAR
    elseif mattype == 'D'
        SPARSE_MATRIX_TYPE_DIAGONAL
    else
        throw(ArgumentError(lazy"Unknown matrix type $mattype"))
    end
end

@inline function Base.convert(::Type{sparse_matrix_type_t}, mattype::String)
    if length(mattype) == 1
        return convert(sparse_matrix_type_t, mattype[1])
    elseif mattype == "BT"
        return SPARSE_MATRIX_TYPE_BLOCK_TRIANGULAR
    elseif mattype == "BD"
        return SPARSE_MATRIX_TYPE_BLOCK_DIAGONAL
    else
        throw(ArgumentError(lazy"Unknown matrix type $mattype"))
    end
end

@inline function Base.convert(::Type{sparse_index_base_t}, index::Char)
    if index == '0'
        return SPARSE_INDEX_BASE_ZERO
    elseif index == '1'
        return SPARSE_INDEX_BASE_ONE
    else
        throw(ArgumentError(lazy"Unknown index base $index"))
    end
end

@inline function Base.convert(::Type{sparse_fill_mode_t}, uplo::Char)
    if uplo == 'L'
        SPARSE_FILL_MODE_LOWER
    elseif uplo == 'U'
        SPARSE_FILL_MODE_UPPER
    elseif uplo =='F'
        SPARSE_FILL_MODE_FULL
    else
        throw(ArgumentError(lazy"Unknown fill mode $uplo"))
    end
end

@inline function Base.convert(::Type{sparse_diag_type_t}, diag::Char)
    if diag == 'U'
        SPARSE_DIAG_UNIT
    elseif diag == 'N'
       SPARSE_DIAG_NON_UNIT
    else
        throw(ArgumentError(lazy"Unknown diag type $diag"))
    end
end

@inline function Base.convert(::Type{sparse_layout_t}, layout::Char)
    if layout == 'R'
        SPARSE_LAYOUT_ROW_MAJOR
    elseif layout == 'C'
        SPARSE_LAYOUT_COLUMN_MAJOR
    else
        throw(ArgumentError(lazy"Unknown layout $layout"))
    end
end

@inline function Base.convert(::Type{verbose_mode_t}, verbose::String)
    if verbose == "off"
        SPARSE_VERBOSE_OFF
    elseif verbose == "basic"
        SPARSE_VERBOSE_BASIC
    elseif verbose == "extended"
        SPARSE_VERBOSE_EXTENDED
    else
        throw(ArgumentError(lazy"Unknown verbose mode $verbose"))
    end
end

@inline function Base.convert(::Type{sparse_memory_usage_t}, memory::String)
    if memory == "none"
        SPARSE_MEMORY_NONE
    elseif memory == "aggressive"
        SPARSE_MEMORY_AGGRESSIVE
    else
        throw(ArgumentError(lazy"Unknown memory usage $memory"))
    end
end

@inline Base.convert(::Type{matrix_descr}, matdescr::AbstractString) =
    matrix_descr(convert(sparse_matrix_type_t, matdescr[1]),
                 convert(sparse_fill_mode_t, matdescr[2]),
                 convert(sparse_diag_type_t, matdescr[3]))

# check the correctness of transA (transB etc) argument of MKLSparse calls
check_trans(t::Char) =
    (t in ('C', 'N', 'T')) ||
        throw(ArgumentError(lazy"trans: is '$t', must be 'N', 'T', or 'C'"))

# check matrix sizes for the multiplication-like operation C <- tA[A] * tB[B]
function check_mat_op_sizes(C, A, tA, B, tB;
                            dense_layout::sparse_layout_t = SPARSE_LAYOUT_COLUMN_MAJOR,
                            check_result_rows::Bool = true,
                            check_result_columns::Bool = true)
    mklsize(M::AbstractMatrix, tM::Char) =
        (tM == 'N') == (dense_layout == SPARSE_LAYOUT_COLUMN_MAJOR) ? size(M) : reverse(size(M))
    mklsize(M::AbstractSparseMatrix, tM::Char) =
        tM == 'N' ? size(M) : reverse(size(M))
    mklsize(V::AbstractVector, tV::Char) =
        tV == 'N' ? (size(V, 1), 1) : (1, size(V, 1))
    sizestr(M::AbstractMatrix) =
        dense_layout == SPARSE_LAYOUT_COLUMN_MAJOR ?
            string("[", size(M, 1), ", ", size(M, 2), "]") :
            string("[", size(M, 2), ", ", size(M, 1), "]")
    sizestr(M::AbstractSparseMatrix) =
            string("[", size(M, 1), ", ", size(M, 2), "]")
    sizestr(V::AbstractVector) = string("[", size(V, 1), "]")
    opsym(t) = t == 'T' ? "ᵀ" : t == 'C' ? "ᴴ" : t == 'N' ? "" : "ERROR"

    mA, nA = mklsize(A, tA)
    mB, nB = mklsize(B, tB)
    mC, nC = !isnothing(C) ? mklsize(C, 'N') : (mA, nB)
    if nA != mB || (check_result_rows && mC != mA) || (check_result_columns && nC != nB)
        str = string("arrays had inconsistent dimensions for C = A", opsym(tA), " * B", opsym(tB), ": ",
                     (isnothing(C) ? "" : (sizestr(C) * " = ")),
                     sizestr(A), opsym(tA), " * ", sizestr(B), opsym(tB))
        throw(DimensionMismatch(str))
    end
end

"""
    MKLSparseError

Wraps `MKLSparse.sparse_status_t` error code.
"""
struct MKLSparseError <: Exception
    status::sparse_status_t
end

Base.showerror(io::IO, e::MKLSparseError) =
    print(io, "MKLSparseError(", e.status, ")")

# check the status of MKL call
check_status(status::sparse_status_t) =
    status == SPARSE_STATUS_SUCCESS || throw(MKLSparseError(status))