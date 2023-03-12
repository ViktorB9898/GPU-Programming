
#include <iostream>
#include <stdio.h>
#include <vector>
#include <algorithm>
#include "timer.hpp"

using Vector = std::vector<double>;


__global__ void addition(int n, double *x, double *y, double *z)
{
  int id = blockIdx.x*blockDim.x + threadIdx.x;
  for (size_t i = id; i < n; i += blockDim.x*gridDim.x){
    z[i] = x[i] + y[i];
    //printf("z: %g\n", z[i*k]);
  }
}

__global__ void empty(int n, double *x, double *y, double *z){}

int main(void)
{
    double *x, *y, *z, *d_x, *d_y, *d_z;
    double elapsed;
    
    Vector bandwidth;
    Vector time_kernel_launch;

    Timer timer;
    int reps = 10; // has to be an even number
    
    Vector N_vec = {10,100,1000,10000,50000,100000,500000};
    for (const auto &N : N_vec){
        Vector time_vec;

        // Allocate host memory and initialize
        x = (double*)malloc(N*sizeof(double));
        y = (double*)malloc(N*sizeof(double));
        z = (double*)malloc(N*sizeof(double));

        for (int i = 0; i < N; i++) {
            x[i] = i;
            y[i] = N-1-i;
            z[i] = 0;
        }
        
        // Allocate device memory and copy host data over
        cudaMalloc(&d_x, N*sizeof(double)); 
        cudaMalloc(&d_y, N*sizeof(double));
        cudaMalloc(&d_z, N*sizeof(double));
        
        cudaMemcpy(d_x, x, N*sizeof(double), cudaMemcpyHostToDevice);
        cudaMemcpy(d_y, y, N*sizeof(double), cudaMemcpyHostToDevice);
        cudaMemcpy(d_z, z, N*sizeof(double), cudaMemcpyHostToDevice);
        
        // repetitions
        for (int j = 0; j < reps; j++){

            // MEASURING TIME FROM HERE
            cudaDeviceSynchronize();
            timer.reset();

            empty<<<256, 256>>>(N, d_x, d_y, d_z);
            //addition<<<256, 256>>>(N, d_x, d_y, d_z);

            cudaDeviceSynchronize();
            elapsed = timer.get();
            time_vec.push_back(elapsed);
            
            // TO HERE
        }
        std::sort(time_vec.begin(), time_vec.end());
        time_kernel_launch.push_back(time_vec[reps/2]);
        bandwidth.push_back(3*(N)*sizeof(double)/time_vec[reps/2]*1e-9);
        //printf("Elapsed: %g\n", time);

        cudaMemcpy(z, d_z, N*sizeof(double), cudaMemcpyDeviceToHost);

        cudaFree(d_x);
        cudaFree(d_y);
        cudaFree(d_z);
        free(x);
        free(y);
        free(z);
    }

    printf("s:\n");
    for (const auto& value : time_kernel_launch){
        std::cout << value << "," << std::endl;
    }

    printf("Gb/s:\n");
    for (const auto& value : bandwidth){
        std::cout << value << "," << std::endl;
    }

    return EXIT_SUCCESS;
}
    

