@testset "Demoralization user utils" begin
  @testset "vertexsetsize" begin
    partition_int = [[1, 4], [2, 3, 5], [6], [7, 8]]
    partition_vertex = VertexSet([Vertex(block) for block = partition_int])
    @test (QSWalk.vertexsetsize(partition_vertex)) == 8
    # error test
    @test_throws MethodError QSWalk.vertexsetsize(partition_int)

  end

  @testset "default_local_hamiltonian" begin
    @test QSWalk.default_local_hamiltonian(1) == spzeros(Complex128, 1, 1)
    @test QSWalk.default_local_hamiltonian(3) == sparse([0. im 0.; -im 0 im; 0 -im 0])
  end

  @testset "local_hamiltonian" begin
    #default option
    @test local_hamiltonian(VertexSet([[1], [2, 3]])) == sparse([0.+0im 0 0;0 0 im;0 -im 0])
    @test local_hamiltonian(VertexSet([[1], [2], [3]])) == spzeros(Complex128, 3, 3)
    #by size version
    @test local_hamiltonian(VertexSet([[1, 2], [3, 4]]), Dict(2 =>[0 1; 1 0])) == sparse([0. 1 0 0; 1 0 0 0; 0 0 0 1; 0 0 1 0])
    @test local_hamiltonian(VertexSet([[1], [2], [3]]), Dict(1 =>ones(Float64, (1, 1)))) == speye(Complex128, 3)
    #by index version
    M1 = [1. 2;3 5]
    M2 = zeros(1, 1)+1.
    dict = Dict(Vertex([1, 3]) =>M1, Vertex([2]) =>M2)
    @test local_hamiltonian(VertexSet([[1, 3], [2]]), dict) ==
            sparse([ 1.0+0im 0 2; 0 1 0; 3 0 5 ])
  end

  @testset "Incidence and reverse incidence lists" begin
    A = [1 2 3; 0 3. 4.; 0 0 5.]
    @test QSWalk.incidence_list(A) == [[1], [1, 2], [1, 2, 3]]
    @test QSWalk.incidence_list(sparse(A)) == QSWalk.incidence_list(A)
    @test QSWalk.incidence_list(A; epsilon = 2.5) == [Int64[], [2], [1, 2, 3]]
    @test QSWalk.incidence_list(sparse(A)) == QSWalk.incidence_list(A)
    @test QSWalk.reversed_incidence_list(A) == [[1, 2, 3], [2, 3], [3]]
    @test QSWalk.reversed_incidence_list(sparse(A)) == QSWalk.reversed_incidence_list(A)
    @test QSWalk.reversed_incidence_list(A; epsilon = 2.5) == [[3], [2, 3], [3]]
    @test QSWalk.reversed_incidence_list(sparse(A); epsilon = 2.5) == QSWalk.reversed_incidence_list(A; epsilon = 2.5)
    #errors
    @test_throws ArgumentError QSWalk.reversed_incidence_list(A, epsilon = -1)
    @test_throws ArgumentError QSWalk.incidence_list(A, epsilon = -1)
    @test_throws ArgumentError QSWalk.reversed_incidence_list(sparse(A), epsilon = -1)
    @test_throws ArgumentError QSWalk.incidence_list(sparse(A), epsilon = -1)
  end

  @testset "vertexset creation" begin
    @test QSWalk.revinc_to_vertexset([[1, 3], [2, 3], Int[], [4, 6, 1]]) == VertexSet([[1, 2], [3, 4], [5], [6, 7, 8]])
    @test make_vertex_set([1 2 3; 0 3. 4.; 0 0 5.]) == VertexSet([[1, 2, 3], [4, 5], [6]])
  end

  @testset "Fourier matrix" begin
    @test QSWalk.fourier_matrix(4) ≈ [1 1 1 1; 1 1im -1 -1im;1 -1 1 -1; 1 -1im -1 1im]
    @test QSWalk.fourier_matrix(2) ≈ [1 1; 1 -1.]
    @test QSWalk.fourier_matrix(1) ≈ ones(Float64, (1, 1))
  end

  @testset "nonmoralizing_lindbladian" begin
    A = sparse([0.+0.0im 1 0; 1 0 1; 0 1 0])
    B1, B2 = eye(1), ones(2, 2)
    #default
    #needs to be roughly, since exp computing is inexact
    @test nonmoralizing_lindbladian(A)[1] ≈ [0 1 1 0;
                                             1 0 0 1;
                                             1 0 0 -1;
                                             0 1 1 0]
    @test nonmoralizing_lindbladian(A)[2] == make_vertex_set(A)

    A = sparse([0.+0.0im 0 0 0 1;
                0 0 1 0 1;
                0 0 0 0 0;
                0 1 1 0 0;
                0 0 0 0 0])
    L, vset = nonmoralizing_lindbladian(A)
    v1, v2, v3, v4, v5 = vlist(vset)
    @test nonmoralizing_lindbladian(A)[1] ≈ [0 0 0 0 0 0 1;
                                             0 0 0 1 0 0 1;
                                             0 0 0 1 0 0 -1;
                                             0 0 0 0 0 0 0;
                                             0 1 1 1 0 0 0;
                                             0 1 1 -1 0 0 0;
                                             0 0 0 0 0 0 0]
    @test nonmoralizing_lindbladian(A)[2] == make_vertex_set(A)
    @test nonmoralizing_lindbladian(A, Dict(v1 => B1, v2 => 2*B2, v3 => 3*B1, v4 => 4*B2, v5 => 5*B1))[1] ≈
             [0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  1.0+0.0im;
              0.0+0.0im  0.0+0.0im  0.0+0.0im  2.0+0.0im  0.0+0.0im  0.0+0.0im  2.0+0.0im;
              0.0+0.0im  0.0+0.0im  0.0+0.0im  2.0+0.0im  0.0+0.0im  0.0+0.0im  2.0+0.0im;
              0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              0.0+0.0im  4.0+0.0im  4.0+0.0im  4.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              0.0+0.0im  4.0+0.0im  4.0+0.0im  4.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im]



    A = [0 0 0; 0 0 0; 1 1 0]
    @test nonmoralizing_lindbladian(A)[1] ≈ [0 0 0 0;
                                             0 0 0 0;
                                             1 1 0 0;
                                             1 -1 0 0]
    @test nonmoralizing_lindbladian(A)[2] == make_vertex_set(A)


    @test nonmoralizing_lindbladian(A, Dict(1  => B1, 2 =>3*B2 ))[1] ≈
             [0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              3.0+0.0im  3.0+0.0im  0.0+0.0im  0.0+0.0im;
              3.0+0.0im  3.0+0.0im  0.0+0.0im  0.0+0.0im]
    @test nonmoralizing_lindbladian(A, Dict(1  => B1, 2 =>3*B2 ))[2] ==
      make_vertex_set(A)

    @test nonmoralizing_lindbladian(A, Dict(1  => B1, 2 =>3*B2 ))[1] ≈
             [0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              3.0+0.0im  3.0+0.0im  0.0+0.0im  0.0+0.0im;
              3.0+0.0im  3.0+0.0im  0.0+0.0im  0.0+0.0im]

    L, vset = nonmoralizing_lindbladian(A)
    v1, v2, v3 = vlist(vset)
    @test nonmoralizing_lindbladian(A, Dict(v1 => B1, v2 => 2*B1, v3 => 3*B2))[1] ≈
             [0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
              3.0+0.0im  3.0+0.0im  0.0+0.0im  0.0+0.0im;
              3.0+0.0im  3.0+0.0im  0.0+0.0im  0.0+0.0im]
    @test nonmoralizing_lindbladian(A, Dict(v1 => B1, v2 => 2*B1, v3 => 3*B2))[2] ==
      make_vertex_set(A)

  end

  @testset "global_hamiltonian" begin
    A = sparse([0 1 0;
               1 0 2;
               0 2 0])
    #default
    #needs to be roughly, since exp computing is inexact
    @test global_hamiltonian(A) ≈ [0 1 1 0;
                                   1 0 0 2;
                                   1 0 0 2;
                                   0 2 2 0]
    @test global_hamiltonian(A, Dict((1, 2) => (2+1im)*ones(1, 2), (2, 1) =>1im*ones(2, 1))) ≈
                                    [0 2+1im 2+1im 0;
                                     2-1im 0 0 2im;
                                     2-1im 0 0 2im;
                                     0 -2im -2im 0]

    v1, v2, v3 = vlist(make_vertex_set(A))
    @test global_hamiltonian(A, Dict((v1, v2) =>2*ones(1, 2), (v2, v3) =>[1im 2im;]')) ==
                                              [0 2 2 0;
                                               2 0 0 2im;
                                               2 0 0 4im;
                                               0 -2im -4im 0]
   A = [0  0  1;
        0  0  1;
        2  2  0]
  v1, v2, v3 = vlist(make_vertex_set(A))
  @test global_hamiltonian(A, Dict((v1, v3) =>2*ones(1, 2), (v2, v3) =>[1im 2im;])) ≈
                          [0.0+0.0im  0.0+0.0im  2.0+0.0im  2.0+0.0im;
                           0.0+0.0im  0.0+0.0im  0.0-1.0im  0.0-2.0im;
                           2.0+0.0im  0.0+1.0im  0.0+0.0im  0.0+0.0im;
                           2.0+0.0im  0.0+2.0im  0.0+0.0im  0.0+0.0im]

  @test global_hamiltonian(A, Dict((v1, v3) =>2*ones(1, 2), (v2, v3) =>[1im 2im;]),epsilon=1.5) ≈
                          [0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
                           0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
                           0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im;
                           0.0+0.0im  0.0+0.0im  0.0+0.0im  0.0+0.0im]

  end
end
