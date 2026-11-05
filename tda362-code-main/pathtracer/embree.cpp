#include "embree.h"
#include <iostream>
#include <map>


using namespace std;
using namespace glm;

namespace pathtracer
{
///////////////////////////////////////////////////////////////////////////
// Global variables
///////////////////////////////////////////////////////////////////////////
RTCDevice embree_device = nullptr;
RTCScene embree_scene = nullptr;

///////////////////////////////////////////////////////////////////////////
// Build an acceleration structure for the scene
///////////////////////////////////////////////////////////////////////////
void buildBVH()
{
	cout << "Embree building BVH..." << flush;
	rtcCommitScene(embree_scene);
	cout << "done.\n";
}

///////////////////////////////////////////////////////////////////////////
// Called when there is an embree error
///////////////////////////////////////////////////////////////////////////
void embreeErrorHandler(void* userval, const RTCError code, const char* str)
{
	cout << "Embree ERROR: " << str << endl;
	exit(1);
}

///////////////////////////////////////////////////////////////////////////
// Used to map an Embree geometry ID to our scene Meshes and Materials
///////////////////////////////////////////////////////////////////////////
map<uint32_t, const labhelper::Model*> map_geom_ID_to_model;
map<uint32_t, const labhelper::Mesh*> map_geom_ID_to_mesh;

void initEmbree()
{
	///////////////////////////////////////////////////////////////////////
	// Lazy initialize embree on first use
	///////////////////////////////////////////////////////////////////////
	static bool embree_is_initialized = false;
	if(!embree_is_initialized)
	{
		cout << "Initializing embree..." << flush;
		embree_is_initialized = true;
		embree_device = rtcNewDevice(nullptr);
		rtcSetDeviceErrorFunction(embree_device, embreeErrorHandler, nullptr);
		cout << "done.\n";
	}
}

void reinitScene()
{
	initEmbree();

	if(embree_scene)
	{
		rtcReleaseScene(embree_scene);
	}

	map_geom_ID_to_model.clear();
	map_geom_ID_to_mesh.clear();
	embree_scene = rtcNewScene(embree_device);
}

///////////////////////////////////////////////////////////////////////////
// Add a model to the embree scene
///////////////////////////////////////////////////////////////////////////
void addModel(const labhelper::Model* model, const mat4& model_matrix)
{
	///////////////////////////////////////////////////////////////////////
	// Lazy initialize embree on first use
	///////////////////////////////////////////////////////////////////////
	if(!embree_scene)
	{
		reinitScene();
	}

	///////////////////////////////////////////////////////////////////////
	// Transform and add each mesh in the model as a geometry in embree,
	// and create mappings so that we can connect an embree geom_ID to a
	// Material.
	///////////////////////////////////////////////////////////////////////
	cout << "Adding " << model->m_name << " to embree scene..." << flush;
	for(auto& mesh : model->m_meshes)
	{
		RTCGeometry geometry = rtcNewGeometry(embree_device, RTC_GEOMETRY_TYPE_TRIANGLE);
		// Transform and commit vertices
		vec4* embree_vertices = static_cast<vec4*>(rtcSetNewGeometryBuffer(geometry, RTC_BUFFER_TYPE_VERTEX, 0,
		    RTC_FORMAT_FLOAT3, sizeof(vec4), mesh.m_number_of_vertices));
		for(uint32_t i = 0; i < mesh.m_number_of_vertices; i++)
		{
			embree_vertices[i] = model_matrix * vec4(model->m_positions[mesh.m_start_index + i], 1.0f);
		}
		// Commit triangle indices
		uint32_t* embree_tri_idxs = static_cast<uint32_t*>(rtcSetNewGeometryBuffer(geometry, RTC_BUFFER_TYPE_INDEX, 0,
		    RTC_FORMAT_UINT3, 3 * sizeof(uint32_t), mesh.m_number_of_vertices / 3));
		for(uint32_t i = 0; i < mesh.m_number_of_vertices; i++)
		{
			embree_tri_idxs[i] = i;
		}
		rtcCommitGeometry(geometry);
		uint32_t geom_ID = rtcAttachGeometry(embree_scene, geometry);
		rtcReleaseGeometry(geometry); // The scene retains its own reference.
		map_geom_ID_to_mesh[geom_ID] = &mesh;
		map_geom_ID_to_model[geom_ID] = model;
	}
	cout << "done.\n";
}

///////////////////////////////////////////////////////////////////////////
// Extract an intersection from an embree ray.
///////////////////////////////////////////////////////////////////////////
Intersection getIntersection(const Ray& r)
{
	const labhelper::Model* model = map_geom_ID_to_model[r.geomID];
	const labhelper::Mesh* mesh = map_geom_ID_to_mesh[r.geomID];
	Intersection i;
	i.material = &(model->m_materials[mesh->m_material_idx]);
	vec3 n0 = model->m_normals[((mesh->m_start_index / 3) + r.primID) * 3 + 0];
	vec3 n1 = model->m_normals[((mesh->m_start_index / 3) + r.primID) * 3 + 1];
	vec3 n2 = model->m_normals[((mesh->m_start_index / 3) + r.primID) * 3 + 2];
	float w = 1.0f - (r.u + r.v);
	i.shading_normal = normalize(w * n0 + r.u * n1 + r.v * n2);
	// Embree 3+ uses the standard winding normal; the Embree 2 sign flip
	// would bias secondary rays into the surface and cause self-shadowing.
	i.geometry_normal = normalize(r.n);
	i.position = r.o + r.tfar * r.d;
	i.wo = normalize(-r.d);

	vec2 uv0 = model->m_texture_coordinates[((mesh->m_start_index / 3) + r.primID) * 3 + 0];
	vec2 uv1 = model->m_texture_coordinates[((mesh->m_start_index / 3) + r.primID) * 3 + 1];
	vec2 uv2 = model->m_texture_coordinates[((mesh->m_start_index / 3) + r.primID) * 3 + 2];
	i.uv = w * uv0 + r.u * uv1 + r.v * uv2;
	return i;
}

///////////////////////////////////////////////////////////////////////////
// Test a ray against the scene and find the closest intersection
///////////////////////////////////////////////////////////////////////////
namespace
{
RTCRay toEmbreeRay(const Ray& r)
{
	RTCRay ray = {};
	ray.org_x = r.o.x;
	ray.org_y = r.o.y;
	ray.org_z = r.o.z;
	ray.dir_x = r.d.x;
	ray.dir_y = r.d.y;
	ray.dir_z = r.d.z;
	ray.tnear = r.tnear;
	ray.tfar = r.tfar;
	ray.time = r.time;
	ray.mask = r.mask;
	return ray;
}
}

bool intersect(Ray& r)
{
	RTCRayHit query = {};
	query.ray = toEmbreeRay(r);
	query.hit.geomID = RTC_INVALID_GEOMETRY_ID;
	query.hit.primID = RTC_INVALID_GEOMETRY_ID;
	for(auto& id : query.hit.instID)
		id = RTC_INVALID_GEOMETRY_ID;
	rtcIntersect1(embree_scene, &query);
	r.geomID = query.hit.geomID;
	r.primID = query.hit.primID;
	r.instID = query.hit.instID[0];
	if(r.geomID == RTC_INVALID_GEOMETRY_ID)
		return false;
	r.tfar = query.ray.tfar;
	r.n = vec3(query.hit.Ng_x, query.hit.Ng_y, query.hit.Ng_z);
	r.u = query.hit.u;
	r.v = query.hit.v;
	return true;
}

///////////////////////////////////////////////////////////////////////////
// Test whether a ray is intersected by the scene (do not return an
// intersection).
///////////////////////////////////////////////////////////////////////////
bool occluded(Ray& r)
{
	RTCRay query = toEmbreeRay(r);
	rtcOccluded1(embree_scene, &query);
	// Embree 4 signals an occluder with negative tfar, not a geometry ID.
	return query.tfar < 0.0f;
}
} // namespace pathtracer