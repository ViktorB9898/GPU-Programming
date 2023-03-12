#include <stdio.h>
#include <iostream>
#include "timer.hpp"
#include "cuda_errchk.hpp" // for error checking of CUDA calls
#include <vector>
#include <algorithm>

__global__ void transpose(double *A, double *B, int N)
{
    int t_idx = blockIdx.x * blockDim.x + threadIdx.x;
    // loop for the case N*N > number of threads
    for (size_t i = t_idx; i < (N*N); i += blockDim.x*gridDim.x){
        int row_idx = i / N;
        int col_idx = i % N;
        B[row_idx * N + col_idx] = A[col_idx * N + row_idx];
    }
}

void print_A(double *A, int N)
{
    for (int i = 0; i < N; i++)
    {
        for (int j = 0; j < N; ++j)
        {
            std::cout << A[i * N + j] << ", ";
        }
        std::cout << std::endl;
    }
}

int main(void)
{
    //int N = 33;
    std::vector<double> N_vec = {16,32,64,128,256,512,1024,2048,4096,8192,16384};
    std::vector<double> bandwidth;

    // declare A and B
    double *A, *B, *cuda_A, *cuda_B;
    Timer timer;
    int reps = 6;

    for (const auto &N : N_vec){
        std::vector<double> time_vec;

        // Allocate host memory and initialize
        A = (double *)malloc(N * N * sizeof(double));
        B = (double *)malloc(N * N * sizeof(double));

        for (int i = 0; i < N * N; i++)
        {
            A[i] = i;
            B[i] = 0;
        }

        //print_A(A, N);
        //print_A(B, N);

        // Allocate device memory and copy host data over
        CUDA_ERRCHK(cudaMalloc(&cuda_A, N * N * sizeof(double)));
        CUDA_ERRCHK(cudaMalloc(&cuda_B, N * N * sizeof(double)));

        // copy data over
        CUDA_ERRCHK(cudaMemcpy(cuda_A, A, N * N * sizeof(double), cudaMemcpyHostToDevice));
        CUDA_ERRCHK(cudaMemcpy(cuda_B, B, N * N * sizeof(double), cudaMemcpyHostToDevice));

        // repetitions
        for (int j = 0; j < reps; j++){
            // wait for previous operations to finish, then start timings
            CUDA_ERRCHK(cudaDeviceSynchronize());
            timer.reset();

            // Perform the transpose operation
            transpose<<<(N + 255) / 256, 256>>>(cuda_A, cuda_B, N);

            // wait for kernel to finish, then print elapsed time
            CUDA_ERRCHK(cudaDeviceSynchronize());
            time_vec.push_back(timer.get());
        }
        std::sort(time_vec.begin(), time_vec.end());
        bandwidth.push_back(4*N*N*sizeof(double)/time_vec[reps/2]*1e-9);

        // copy data back (implicit synchronization point)
        CUDA_ERRCHK(cudaMemcpy(A, cuda_A, N * N * sizeof(double), cudaMemcpyDeviceToHost));
        CUDA_ERRCHK(cudaMemcpy(B, cuda_B, N * N * sizeof(double), cudaMemcpyDeviceToHost));

        //print_A(B, N);

        cudaFree(cuda_A);
        free(A);
        cudaFree(cuda_B);
        free(B);
    }

    printf("Gb/s:\n");
    for (const auto& value : bandwidth){
        std::cout << value << "," << std::endl;
    }

    CUDA_ERRCHK(cudaDeviceReset()); // for CUDA leak checker to work

    return EXIT_SUCCESS;
}
