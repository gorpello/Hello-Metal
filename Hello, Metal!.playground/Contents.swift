import PlaygroundSupport
import MetalKit

// Chack if device is Metal friendly...
guard let device = MTLCreateSystemDefaultDevice() else {
  fatalError("Metal is not supported")
}

// Create a frame for the canvas
let frame = CGRect(x: 0, y: 0, width: 600, height: 600)

// Create a Metal View for rendering
let view = MTKView(frame: frame, device: device)

// Set the color of the View
view.clearColor = MTLClearColor(red: 1,
                                green: 1,
                                blue: 0.8,
                                alpha: 1)


// The allocator manages the memory for the mesh data.
let allocator = MTKMeshBufferAllocator(device: device)

// Creates a sphere with the specified size and returns an MDLMesh
// with all the vertex information in data buffers.
let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75, 0.75],
                      segments: [100, 100],
                      inwardNormals: false,
                      geometryType: .triangles,
                      allocator: allocator)

// Convert it from a Model I/O mesh to a MetalKit mesh.
let mesh = try MTKMesh(mesh: mdlMesh, device: device)

// Create a new command Queue
guard let commandQueue = device.makeCommandQueue() else {
  fatalError("Could not create a command queue")
}

// Shader functions are small programs that run on the GPU.
let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float4 position [[attribute(0)]];
};

vertex float4 vertex_main(const VertexIn vertex_in [[stage_in]]) {
  return vertex_in.position;
}

fragment float4 fragment_main() {
  return float4(1, 0, 0, 1);
}
"""

// Create a library from the shader
let library = try device.makeLibrary(source: shader, options: nil)

// Create a reference to the functions
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction = library.makeFunction(name: "fragment_main")

// Pipeline state for the GPU, create it through a descriptor.
// This descriptor holds everything the pipeline needs to know
let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
pipelineDescriptor.vertexFunction = vertexFunction
pipelineDescriptor.fragmentFunction = fragmentFunction

// You’ll describe to the GPU how the vertices are laid out in memory using a vertex descriptor.
pipelineDescriptor.vertexDescriptor =
  MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

// Creates the pipeline state from the descriptor.
let pipelineState =
  try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

// This stores all the commands that you’ll ask the GPU to run.
guard let commandBuffer = commandQueue.makeCommandBuffer(),
// Obtain a reference to the view’s render pass descriptor. The descriptor holds data for the render destinations, known as attachments.
  let renderPassDescriptor = view.currentRenderPassDescriptor,
// The render command encoder holds all the information necessary to send to the GPU so that it can draw the vertices.
  let renderEncoder = commandBuffer.makeRenderCommandEncoder(
    descriptor: renderPassDescriptor)
else { fatalError() }

// This code gives the render encoder the pipeline state that you set up earlier.
renderEncoder.setRenderPipelineState(pipelineState)

// Give this buffer to the render encoder
renderEncoder.setVertexBuffer(
  mesh.vertexBuffers[0].buffer, offset: 0, index: 0)

// 3D models are designed with different material groups. These translate to submeshes.
guard let submesh = mesh.submeshes.first else {
  fatalError()
}

// You’re instructing the GPU to render a vertex buffer consisting of triangles with the vertices placed in the correct order
renderEncoder.drawIndexedPrimitives(
  type: .triangle,
  indexCount: submesh.indexCount,
  indexType: submesh.indexType,
  indexBuffer: submesh.indexBuffer.buffer,
  indexBufferOffset: 0)

// Tell the render encoder that there are no more draw calls and end the render pass.
renderEncoder.endEncoding()

// Get the drawable from the MTKView
guard let drawable = view.currentDrawable else {
  fatalError()
}

// Ask the command buffer to present the MTKView’s drawable and commit to the GPU.
commandBuffer.present(drawable)
commandBuffer.commit()

// Run the playground with the view
PlaygroundPage.current.liveView = view
