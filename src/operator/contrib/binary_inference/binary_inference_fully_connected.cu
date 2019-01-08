/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
/*!
 * Copyright (c) 2018 by Contributors
 * \file binary_inference_convolution-inl.h
 * \brief
 * \ref: https://arxiv.org/abs/1705.09864
 * \author HPI-DeepLearning
*/

#include "./binary_inference_fully_connected-inl.h"
#include <mshadow/tensor.h>
#include "./xnor_kernels.h"

namespace mshadow {
namespace cuda {

/*
 *  m: batch size
 *  n: input_dim e.g. 1024
 *  k: hidden_num e.g. 1000
 */
inline void _BinaryInferenceFullyConnectedForward(int m, int n, int k,
                                                 const Tensor<gpu, 2, float> &data,
                                                 Tensor<gpu, 1, float> &workspace,
                                                 mxnet::op::xnor::BINARY_WORD* wmat_binarized,
                                                 Tensor<gpu, 2, float> &out) {
                                      
  CHECK_EQ(workspace.shape_.Size() * sizeof(workspace[0]) * CHAR_BIT, n * m);         
  int basic_factor_nchannel_input = BITS_PER_BINARY_WORD;
  cudaStream_t stream = Stream<gpu>::GetStream(out.stream_);

  //set memory
  float *fA = data.dptr_; 
  // float *fB = wmat.dptr_;
  float *fC = out.dptr_;  
  BINARY_WORD* binary_row = (BINARY_WORD*) workspace.dptr_;
        
  //concatinates matrix (m x n) -> (m x n/32)
  int threads_per_block = BLOCK_SIZE_XNOR;
  dim3 conc_block(threads_per_block, 1, 1);
  dim3 conc_grid(m*n/(threads_per_block*basic_factor_nchannel_input)+1,1);
  concatenate_rows_kernel<<<conc_grid, conc_block, 0, stream>>>(fA, binary_row, m*n/basic_factor_nchannel_input);

  //perform xnor gemm
  threads_per_block = BLOCK_SIZE_XNOR;
  dim3 block(threads_per_block, threads_per_block);
  dim3 grid(k / threads_per_block + 1, m / threads_per_block + 1);
  xnor_gemm<<<grid, block, 0, stream>>>(binary_row, wmat_binarized, fC, m, n/basic_factor_nchannel_input, k);   
  cudaDeviceSynchronize();        
}
}  // namespace cuda
  
  inline void BinaryInferenceFullyConnectedForward(int m, int n, int k,
                                     const Tensor<gpu, 2, float> &data,
                                     Tensor<gpu, 1, float> &workspace,
                                     mxnet::op::xnor::BINARY_WORD* wmat_binarized,
                                     Tensor<gpu, 2, float> &out) {
    cuda::_BinaryInferenceFullyConnectedForward(m, n, k, data, workspace, wmat_binarized, out);
  }

  inline void BinaryInferenceFullyConnectedForward(int m, int n, int k,
                                     const Tensor<gpu, 2, float> &data,
                                     Tensor<gpu, 1, float> &workspace,
                                     const Tensor<gpu, 2, float> &wmat,
                                     Tensor<gpu, 2, float> &out) {    
    CHECK(false) << "cuda for non-concatenated weights not implemented"; 
  }

  template<typename DType>
  inline void BinaryInferenceFullyConnectedForward(int m, int n, int k,
                                     const Tensor<gpu, 2, DType> &data,
                                     Tensor<gpu, 1, DType> &workspace,
                                     mxnet::op::xnor::BINARY_WORD* wmat_binarized,
                                     Tensor<gpu, 2, DType> &out) {
    CHECK(false) << "only float supported";
  }

  template<typename DType>
  inline void BinaryInferenceFullyConnectedForward(int m, int n, int k,
                                     const Tensor<gpu, 2, DType> &data,
                                     Tensor<gpu, 1, DType> &workspace,
                                     const Tensor<gpu, 2, DType> &wmat,
                                     Tensor<gpu, 2, DType> &out) {
    CHECK(false) << "only float supported";
  }
} // namespace mshadow


namespace mxnet {
namespace op {
template<>
Operator* CreateOp<gpu>(BinaryInferenceFullyConnectedParam param, int dtype,
                        std::vector<TShape> *in_shape,
                        std::vector<TShape> *out_shape,
                        Context ctx) {
  Operator *op = NULL;
  MSHADOW_REAL_TYPE_SWITCH(dtype, DType, {
    op = new BinaryInferenceFullyConnectedOp<gpu, DType>(param);
  })
  return op;
}
}  // namespace op
}  // namespace mxnet
