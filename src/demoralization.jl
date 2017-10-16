export
  local_hamiltonian,
  nonmoralizing_lindbladian,
  make_vertex_set,
  global_hamiltonian

"""

    default_local_hamiltonian(size)

Returns default local hamiltonian of size `size`×`size` for the demoralization
procedure. The hamiltonian is sparse and the only nonzero elements are on the
first upperdiagonal (equal to `1im`) and lowerdiagonal (equal to `-1im`). This
function is used to provide the default argument for `local_hamiltonian`
function.

# Examples

```jldoctest
julia> QSWalk.default_local_hamiltonian(4)
4×4 SparseMatrixCSC{Complex{Float64},Int64} with 6 stored entries:
  [2, 1]  =  0.0-1.0im
  [1, 2]  =  0.0+1.0im
  [3, 2]  =  0.0-1.0im
  [2, 3]  =  0.0+1.0im
  [4, 3]  =  0.0-1.0im
  [3, 4]  =  0.0+1.0im
```
"""
function default_local_hamiltonian(size::Int)
  @argument size>0 "Size of default local hamiltonian needs to be positive"
  if size == 1
    return spzeros(Complex128,1,1)
  else
    spdiagm((im*ones(size-1),-im*ones(size-1)),(1,-1))
  end
end

"""

    local_hamiltonian(vertexset[, hamiltoniansByDegree])
    local_hamiltonian(vertexset, hamiltoniansByVertex)

Creates hamiltonian which works locally on each vertex from `vertexset` linear
subspace. Depending the form given, `hamiltoniansByDegree` is a dictionary
`Dict{Int,SparseDenseMatrix}`, which for a given dimension of vertex linear
subspace yields some hermitian operator. Only matrices for existing dimensions
needs to be specified. `hamiltoniansByVertex` is a dictionary
`Dict{Vertex,SparseDenseMatrix}`, which for given vertex yield hermitian
operator of the size equal to the dimension of subspace corresponding to the
vertex.

*Note* Value of `vertexset` should be generated by `nonmoralizing_lindbladian` in order
to match demoralization procedure. Numerical analysis [1] suggests, that
hamiltonians should be complex valued.

[1] K. Domino, A. Glos, M. Ostaszewski, Superdiffusive quantum stochastic walk
definable on arbitrary directed graph, Quantum Information & Computation,
Vol.17 No.11&12, pp. 0973-0986, arXiv:1701.04624.

# Examples

```jldoctest
julia> vset = VertexSet([[1,2],[3,4]])
QSWalk.VertexSet(QSWalk.Vertex[QSWalk.Vertex([1, 2]), QSWalk.Vertex([3, 4])])

julia> full(local_hamiltonian(vset))
4×4 Array{Complex{Float64},2}:
 0.0+0.0im  0.0+1.0im  0.0+0.0im  0.0+0.0im
 0.0-1.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im
 0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+1.0im
 0.0+0.0im  0.0+0.0im  0.0-1.0im  0.0+0.0im

julia> A, B = rand(2,2), rand(2,2)
([0.358914 0.183322; 0.379927 0.671986], [0.26643 0.969279; 0.313752 0.636789])

julia> v1, v2 = vset()
2-element Array{QSWalk.Vertex,1}:
 QSWalk.Vertex([1, 2])
 QSWalk.Vertex([3, 4])

julia> local_hamiltonian(vset, Dict(v1 => A, v2 => B))
4×4 SparseMatrixCSC{Complex{Float64},Int64} with 8 stored entries:
  [1, 1]  =  0.358914+0.0im
  [2, 1]  =  0.379927+0.0im
  [1, 2]  =  0.183322+0.0im
  [2, 2]  =  0.671986+0.0im
  [3, 3]  =  0.26643+0.0im
  [4, 3]  =  0.313752+0.0im
  [3, 4]  =  0.969279+0.0im
  [4, 4]  =  0.636789+0.0im

julia> local_hamiltonian(VertexSet([[1,2],[3,4]]), Dict(2 => A))
4×4 SparseMatrixCSC{Complex{Float64},Int64} with 8 stored entries:
  [1, 1]  =  0.358914+0.0im
  [2, 1]  =  0.379927+0.0im
  [1, 2]  =  0.183322+0.0im
  [2, 2]  =  0.671986+0.0im
  [3, 3]  =  0.358914+0.0im
  [4, 3]  =  0.379927+0.0im
  [3, 4]  =  0.183322+0.0im
  [4, 4]  =  0.671986+0.0im
```
"""
function local_hamiltonian(vertexset::VertexSet,
                           hamiltonians::Dict{Int,T} where T<:AbstractArray
                             =Dict(l=>default_local_hamiltonian(l) for l=length.(vertexset())))
  @argument all([typeof(h)<:SparseDenseMatrix for h=values(hamiltonians)]) "All elements in `hamiltonians` must be SparseMatrixCSC or Matrix"
  @argument all([eltype(h)<:Number for h=values(hamiltonians)]) "All elements of elements in `hamiltonians` must be Number"
  @argument all([size(h, 1) == size(h, 2) for h=values(hamiltonians)])  "hamiltonians must consists of square matrices"
  verticeslengths = length.(vertexset())
  @assert all([l in keys(hamiltonians) for l=verticeslengths]) "Missing degree in the Dictionary: $verticeslengths needed"

  hamiltonianlist = Dict{Vertex,SparseDenseMatrix}(v=>hamiltonians[length(v)] for v=vertexset())
  local_hamiltonian(vertexset, hamiltonianlist)
end

function local_hamiltonian(vertexset::VertexSet,
                           hamiltonians::Dict{Vertex,T} where T)
  @argument all([typeof(h)<:SparseDenseMatrix for h=values(hamiltonians)]) "All elements in `hamiltonians` must be SparseMatrixCSC or Matrix"
  @argument all([eltype(h)<:Number for h=values(hamiltonians)]) "All elements of elements in `hamiltonians` must be Number"
  @argument all([size(h, 1) == size(h, 2) for h=values(hamiltonians)])  "hamiltonians must consists of square matrices"
  @assert all([v in keys(hamiltonians) for v=vertexset()]) "Missing hamiltonian for some vertex"
  @assert all([length(v)==size(hamiltonians[v], 1) for v=vertexset()]) "The vertex length and hamiltonian size do no match"

  result = spzeros(Complex128,vertexsetsize(vertexset),vertexsetsize(vertexset))
  for vertex=vertexset()
    result[vertex(),vertex()] = hamiltonians[vertex]
  end
  result
end

"""

    incidence_list(A[; epsilon])

For given matrix `A` the function returns list of indices. The `i`-th element of
result list is the vector of indices for which `abs(A[j,i]) >= epsilon`.

# Examples

```jldoctest
julia> A = [1 2 3; 0 3. 4.; 0 0 5.]
3×3 Array{Float64,2}:
 1.0  2.0  3.0
 0.0  3.0  4.0
 0.0  0.0  5.0

julia> QSWalk.incidence_list(A)
3-element Array{Array{Int64,1},1}:
 [1]
 [1,2]
 [1,2,3]

julia> QSWalk.incidence_list(A, epsilon=2.5)
3-element Array{Array{Int64,1},1}:
  Int64[]
  [2]
  [1,2,3]

```
"""
function incidence_list(A::SparseMatrixCSC{T} where T<:Number;
                        epsilon::Real=eps())
  @argument epsilon >= 0 "epsilon needs to be nonnegative"
  @argument size(A, 1) == size(A, 2) "A matrix must be square"
  [filter(x -> abs(A[x,i])>=epsilon, A[:,i].nzind) for i=1:size(A,1)]
end

function incidence_list(A::Matrix{T} where T<:Number;
                        epsilon::Real=eps())
  @argument epsilon >= 0 "epsilon needs to be nonnegative"
  @argument size(A, 1) == size(A, 2) "A matrix must be square"
  [find(x -> abs(x)>=epsilon, A[:,i]) for i=1:size(A,1)]
end

"""

    reversed_incidence_list(A[; epsilon])

For given matrix `A` the function returns list of indices. The `i`-th element of
result list is the vector of indices for which `abs(A[i,j]) >= epsilon`.

# Examples

```jldoctest
julia> A = [1 2 3; 0 3. 4.; 0 0 5.]
3×3 Array{Float64,2}:
 1.0  2.0  3.0
 0.0  3.0  4.0
 0.0  0.0  5.0

julia> QSWalk.reversed_incidence_list(A)
3-element Array{Array{Int64,1},1}:
 [1,2,3]
 [2,3]
 [3]

julia> QSWalk.reversed_incidence_list(A, epsilon=2.5)
3-element Array{Array{Int64,1},1}:
 [3]
 [2,3]
 [3]
```
"""
function reversed_incidence_list(A::SparseMatrixCSC{T} where T<:Number;
                                 epsilon::Real=eps())
  @argument epsilon >= 0 "epsilon needs to be nonnegative"
  @argument size(A, 1) == size(A, 2) "A matrix must be square"
  [filter(x -> abs(A[i,x])>=epsilon, A[i,:].nzind) for i=1:size(A,1)]
end

function reversed_incidence_list(A::Matrix{T} where T<:Number;
                                 epsilon::Real=eps())
  @argument epsilon >= 0 "epsilon needs to be nonnegative"
  @argument size(A, 1) == size(A, 2) "A matrix must be square"
  [find(x -> abs(x)>=epsilon, A[i,:]) for i=1:size(A,1)]
end

"""

    revinc_to_vertexset(revincidence_list)

Return `vertexset` of type `VertexSet` corresponding to given list of indices.
The function map to consecutive element list orthogonal subspaces. The
dimensions of the subspaces equal to size of each element of revincidence_list.
The exception is empty list, for which onedimensional subspace is attached.

# Examples

```jldoctest
julia> vset = [Int64[],[2],[1,2,3]]
3-element Array{Array{Int64,1},1}:
 Int64[]
 [2]
 [1,2,3]

julia> QSWalk.revinc_to_vertexset(vset)()
3-element Array{QSWalk.Vertex,1}:
 QSWalk.Vertex([1])
 QSWalk.Vertex([2])
 QSWalk.Vertex([3,4,5])

```
"""
function revinc_to_vertexset(revincidence_list::Vector{Vector{Int}})
  vertexset = Vector{Int}[]
  start = 1
  for i=revincidence_list
    if length(i)!=0
      push!(vertexset, collect(start:(start+length(i)-1)))
      start+=length(i)
    else
      push!(vertexset, [start])
      start += 1
    end
  end
  VertexSet(vertexset)
end

"""

    make_vertex_set(A[, epsilon])

Creates object of type `VertexSet` which represents how vertices are located in
matrix. Should be used only in the nondefault use of `global_operator` function.
It is always equal to the second element if output of `global_operator` function.

# Examples

```jldoctest
julia> A = [1 2 3; 0 3. 4.; 0 0 5.]
3×3 Array{Float64,2}:
 1.0  2.0  3.0
 0.0  3.0  4.0
 0.0  0.0  5.0

julia> make_vertex_set(A)()
3-element Array{QSWalk.Vertex,1}:
 QSWalk.Vertex([1, 2, 3])
 QSWalk.Vertex([4, 5])
 QSWalk.Vertex([6])

julia> make_vertex_set(A, epsilon=2.5)()
3-element Array{QSWalk.Vertex,1}:
 QSWalk.Vertex([1])
 QSWalk.Vertex([2, 3])
 QSWalk.Vertex([4])

```
"""
function make_vertex_set(A::SparseDenseMatrix; epsilon::Real=eps())
  @argument epsilon >= 0 "epsilon needs to be nonnegative"
  @argument size(A, 1) == size(A, 2) "A matrix must be square"
  revinc_to_vertexset(reversed_incidence_list(A, epsilon=epsilon))
end

"""

    fourier_matrix(size)

Returns Fourier matrix of size `size`×`size`.

# Examples

```jldoctest
julia> QSWalk.fourier_matrix(1)
1×1 SparseMatrixCSC{Complex{Float64},Int64} with 1 stored entry:
  [1, 1]  =  1.0+0.0im

julia> QSWalk.fourier_matrix(2)
2×2 SparseMatrixCSC{Complex{Float64},Int64} with 4 stored entries:
  [1, 1]  =  1.0+0.0im
  [2, 1]  =  1.0+0.0im
  [1, 2]  =  1.0+0.0im
  [2, 2]  =  -1.0+1.22465e-16im
```
"""
function fourier_matrix(size::Int)
  @argument size>0 "Size of the matrix needs to be positive"
  sparse([exp(2im*π*(i-1)*(j-1)/size) for i=1:size, j=1:size])
end


"""

    nonmoralizing_lindbladian(A[, lindbladians][, epsilon])

Return single Lindbladian operator and vertex set describing how vertices are
bound to subspaces. The Lindbladian operator is constructed according to the
corection scheme presented in [1]. Parameter `A` is square matrix, describing
the connection between the cannonical subspaces similar as adjacency matrix.
Parameter `epsilon`, with the default value `eps()`, determines the relevant
values by `abs(A[i,j]) >= epsilon` formula. List `lindbladians` describes the
elementary matrices used (see [1]). It can be `Dict{Int,SparseDenseMatrix}`,
which returns the matrix by the indegree, or `Dict{Vertex, SparseDenseMatrix}`
which, for different verticex, may return different
matrix. The matrix should have orthogonal columns and be of the size
outdeg of the vertex. As default the function uses Fourier matrices.

*Note* It is expected that for all pair of vertices there exists a matrix in the
`lindbladians` list.

*Note* The orthogonality of matrices in `lindbladians` is not verified.

*Note* The submatrices of the result matrix are multiplied by corresponding `A`
element.

[1] K. Domino, A. Glos, M. Ostaszewski, Superdiffusive quantum stochastic walk
definable on arbitrary directed graph, Quantum Information & Computation,
Vol.17 No.11&12, pp. 0973-0986, arXiv:1701.04624.


# Examples

```jldoctest
julia> A = [0 1 0; 1 0 1; 0 1 0]
3×3 Array{Int64,2}:
 0  1  0
 1  0  1
 0  1  0

julia> L, vset = nonmoralizing_lindbladian(A)
(
  [2, 1]  =  1.0+0.0im
  [3, 1]  =  1.0+0.0im
  [1, 2]  =  1.0+0.0im
  [4, 2]  =  1.0+0.0im
  [1, 3]  =  1.0+0.0im
  [4, 3]  =  1.0+0.0im
  [2, 4]  =  1.0+0.0im
  [3, 4]  =  -1.0+1.22465e-16im, QSWalk.VertexSet(QSWalk.Vertex[QSWalk.Vertex([1]), QSWalk.Vertex([2, 3]), QSWalk.Vertex([4])]))

julia> B1, B2 = 2*eye(1), 3*ones(2,2)
([2.0], [3.0 3.0; 3.0 3.0])

julia> nonmoralizing_lindbladian(A, Dict(1 => B1, 2=>B2 ))
(
  [2, 1]  =  3.0+0.0im
  [3, 1]  =  3.0+0.0im
  [1, 2]  =  2.0+0.0im
  [4, 2]  =  2.0+0.0im
  [1, 3]  =  2.0+0.0im
  [4, 3]  =  2.0+0.0im
  [2, 4]  =  3.0+0.0im
  [3, 4]  =  3.0+0.0im, QSWalk.VertexSet(QSWalk.Vertex[QSWalk.Vertex([1]), QSWalk.Vertex([2, 3]), QSWalk.Vertex([4])]))

julia> v1, v2, v3 = vset()
3-element Array{QSWalk.Vertex,1}:
 QSWalk.Vertex([1])
 QSWalk.Vertex([2, 3])
 QSWalk.Vertex([4])

 julia> nonmoralizing_lindbladian(A, Dict(v1 => ones(1,1), v2 => [2 2; 2 -2], v3=>3*ones(1,1)))[1] |> full
 4×4 Array{Complex{Float64},2}:
  0.0+0.0im  1.0+0.0im  1.0+0.0im   0.0+0.0im
  2.0+0.0im  0.0+0.0im  0.0+0.0im   2.0+0.0im
  2.0+0.0im  0.0+0.0im  0.0+0.0im  -2.0+0.0im
  0.0+0.0im  3.0+0.0im  3.0+0.0im   0.0+0.0im


```
"""

function nonmoralizing_lindbladian(A::SparseDenseMatrix,
                                   lindbladians::Dict{Int,S} where S;
                                   epsilon::Real=eps())
  @argument all([typeof(l)<:SparseDenseMatrix for l=values(lindbladians)]) "All elements in `hamiltonians` must be SparseMatrixCSC or Matrix"
  @argument all([eltype(l)<:Number for l=values(lindbladians)]) "All elements of elements in `hamiltonians` must be Number"
  @argument epsilon>=0 "epsilon needs to be nonnegative"

  revincidence_list = reversed_incidence_list(A, epsilon=epsilon)
  vset = revinc_to_vertexset(revincidence_list)
  verticeslengths = length.(vset())

  @assert all([ l in keys(lindbladians) for l=verticeslengths]) "Missing degrees in lindbladians: $verticeslengths needed"

  L = spzeros(Complex128,vertexsetsize(vset),vertexsetsize(vset))
  for i=1:size(A,1), (index,j)=enumerate(revincidence_list[i]), k in vset[j]()
      L[vset[i](),k] = A[i,j]*lindbladians[length(vset[i])][:,index]
  end
  L, vset
end

function nonmoralizing_lindbladian(A::SparseDenseMatrix;
                                   epsilon::Real=eps())
  vset = make_vertex_set(A, epsilon=epsilon)
  degrees = [length(v) for v=vset()]

  nonmoralizing_lindbladian(A, Dict(d=>fourier_matrix(d) for d=degrees), epsilon=epsilon)
end

function nonmoralizing_lindbladian(A::SparseDenseMatrix,
                                   lindbladians::Dict{Vertex,S} where S;
                                   epsilon::Real=eps())
  @argument all([typeof(l)<:SparseDenseMatrix for l=values(lindbladians)]) "All elements in `hamiltonians` must be SparseMatrixCSC or Matrix"
  @argument all([eltype(l)<:Number for l=values(lindbladians)]) "All elements of elements in `hamiltonians` must be Number"
  @argument all([size(l, 1) == size(l, 2) for l=values(lindbladians)])  "lindbladians should consist of square matrix"
  @argument epsilon>=0 "epsilon needs to be nonnegative"

  revincidence_list = reversed_incidence_list(A; epsilon=epsilon)
  vset = revinc_to_vertexset(revincidence_list)

  @argument all([ v in keys(lindbladians) for v=vset()]) "Some vertex is missing in lindbladians"
  @argument all([ length(v) == size(lindbladians[v], 1) for v=vset()]) "Size of the lindbladians should equal to indegree of the vertex"

  L = spzeros(Complex128,vertexsetsize(vset),vertexsetsize(vset))
  for i=1:size(A,1), (index,j)=enumerate(revincidence_list[i]), l=vset[j]()
      L[vset[i](),l] = A[i,j]*lindbladians[vset[i]][:,index]
  end
  L, vset
end


"""

    global_hamiltonian(A[, hamiltonians][, epsilon])

Creates global hamiltonian for moralization procedure. The function constructs
upper-diagonl of result matrix by upper-diagonal of `A` matrix and after
symmetrizes it. The result matrix is then always exactly hermitian. `hamiltonians`
is an optional argument which is a Dictionary with keys of type `Tuple{Int,Int}`
or `Tuple{Vertex,Vertex}`. First collects the submatrices according to its
shape, while the second collect according to each pair of vertices. As default
all-one submatrices are chosen. Only those elements for which `abs(A[i,j]) >= epsilon`
are considered.

*Note* The submatrices of the result matrix are scaled by corresponding `A`
element.

# Examples

```jldoctest
julia> A = [ 0 1 0; 1 0 1; 0 1 0]
3×3 Array{Int64,2}:
 0  1  0
 1  0  1
 0  1  0

julia> global_hamiltonian(A) |> full
4×4 Array{Complex{Float64},2}:
 0.0+0.0im  1.0+0.0im  1.0+0.0im  0.0+0.0im
 1.0+0.0im  0.0+0.0im  0.0+0.0im  1.0+0.0im
 1.0+0.0im  0.0+0.0im  0.0+0.0im  1.0+0.0im
 0.0+0.0im  1.0+0.0im  1.0+0.0im  0.0+0.0im

julia> global_hamiltonian(A, Dict((1,2)=> (2+1im)*ones(1,2), (2,1)=>1im*ones(2,1))) |> full
4×4 Array{Complex{Float64},2}:
 0.0+0.0im  2.0+1.0im  2.0+1.0im  0.0+0.0im
 2.0-1.0im  0.0+0.0im  0.0+0.0im  0.0+1.0im
 2.0-1.0im  0.0+0.0im  0.0+0.0im  0.0+1.0im
 0.0+0.0im  0.0-1.0im  0.0-1.0im  0.0+0.0im

julia> v1, v2, v3 = make_vertex_set(A)()
3-element Array{QSWalk.Vertex,1}:
^[[A QSWalk.Vertex([1])
 QSWalk.Vertex([2, 3])
 QSWalk.Vertex([4])

julia> global_hamiltonian(A, Dict((v1,v2)=>2*ones(1,2), (v2,v3)=>[1im 2im;]')) |> full
4×4 Array{Complex{Float64},2}:
 0.0+0.0im  2.0+0.0im  2.0+0.0im  0.0+0.0im
 2.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+1.0im
 2.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+2.0im
 0.0+0.0im  0.0-1.0im  0.0-2.0im  0.0+0.0im
```
"""



function global_hamiltonian(A::SparseDenseMatrix,
                            hamiltonians::Dict{Tuple{Int,Int},S} where S;
                            epsilon::Real=eps())
  @argument all([typeof(h)<:SparseDenseMatrix for h=values(hamiltonians)]) "All elements in hamiltonians must be SparseMatrixCSC or Matrix"
  @argument all([eltype(h)<:Number for h=values(hamiltonians)]) "All elements of elements in hamiltonians must be Number"
  @argument epsilon>=0 "epsilon needs to be nonnegative"


  revincidence_list = reversed_incidence_list(A, epsilon=epsilon)
  vset = revinc_to_vertexset(revincidence_list)


  H = spzeros(Complex128, vertexsetsize(vset), vertexsetsize(vset))
  for (index, i)=enumerate(revincidence_list), j=i
    if index < j
      hamiltonianshape = length.((vset[index](), vset[j]()))
      @argument hamiltonianshape in keys(hamiltonians) "hamiltonian of size $hamiltonianshape not found"
      @argument hamiltonianshape == size(hamiltonians[hamiltonianshape]) "hamiltonian for key $(hamiltonianshape) shoud have shape $(hamiltonianshape)"
      H[vset[index](),vset[j]()] = A[index,j]*hamiltonians[hamiltonianshape]
    end
  end
  H + H'
end

function global_hamiltonian(A::SparseDenseMatrix;
                            epsilon::Real=eps())
  #indlist = incidence_list(A, epsilon=epsilon)
  revindlist = reversed_incidence_list(A, epsilon=epsilon)

  alloneshamiltonians = Dict{Tuple{Int,Int},SparseMatrixCSC}()
  for v=revindlist, w=v
    w = revindlist[w]
    alloneshamiltonians[length.((v,w))] = ones(length(v), length(w))
    alloneshamiltonians[length.((w,v))] = ones(length(w), length(v))
  end
  global_hamiltonian(A, alloneshamiltonians, epsilon=epsilon)
end

function global_hamiltonian(A::SparseDenseMatrix,
                            hamiltonians::Dict{Tuple{Vertex,Vertex},S} where S;
                            epsilon::Real=eps())
  @argument all([typeof(h)<:SparseDenseMatrix for h=values(hamiltonians)]) "All elements in hamiltonians must be SparseMatrixCSC or Matrix"
  @argument all([eltype(h)<:Number for h=values(hamiltonians)]) "All elements of elements in hamiltonians must be Number"
  @argument epsilon>=0 "epsilon needs to be nonnegative"


  revincidence_list = reversed_incidence_list(A, epsilon=epsilon)
  vset = revinc_to_vertexset(revincidence_list)


  H = spzeros(Complex128, vertexsetsize(vset), vertexsetsize(vset))
  for (index, i)=enumerate(revincidence_list), j=i
    if index < j
      key = (vset[index], vset[j])
      @argument key in keys(hamiltonians) "hamiltonian for $key not found"
      @argument length.(key) == size(hamiltonians[key]) "hamiltonian for key $key shoud have shape $(length.(key))"
      H[vset[j](),vset[index]()] = A[index,j]*hamiltonians[key].'
    end
  end
  H + H'
end
