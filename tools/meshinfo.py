import pymeshlab
import sys

ms = pymeshlab.MeshSet()
ms.load_new_mesh(sys.argv[1])

mesh = ms.current_mesh()

print(f"vertices: {mesh.vertex_number()}")
print(f"faces:    {mesh.face_number()}")
print(f"edges:    {mesh.edge_number()}")

bbox = mesh.bounding_box()
print(f"bbox:     {bbox}")