#version 420

// required by GLSL spec Sect 4.5.3 (though nvidia does not, amd does)
precision highp float;

///////////////////////////////////////////////////////////////////////////////
// Material
///////////////////////////////////////////////////////////////////////////////
uniform vec3 material_color;
uniform float material_metalness;
uniform float material_fresnel;
uniform float material_shininess;
uniform vec3 material_emission;

uniform int has_color_texture;
layout(binding = 0) uniform sampler2D colorMap;
uniform int has_emission_texture;
layout(binding = 5) uniform sampler2D emissiveMap;

///////////////////////////////////////////////////////////////////////////////
// Environment
///////////////////////////////////////////////////////////////////////////////
layout(binding = 6) uniform sampler2D environmentMap;
layout(binding = 7) uniform sampler2D irradianceMap;
layout(binding = 8) uniform sampler2D reflectionMap;
uniform float environment_multiplier;

///////////////////////////////////////////////////////////////////////////////
// Light source
///////////////////////////////////////////////////////////////////////////////
uniform vec3 point_light_color = vec3(1.0, 1.0, 1.0);
uniform float point_light_intensity_multiplier = 50.0;

///////////////////////////////////////////////////////////////////////////////
// Constants
///////////////////////////////////////////////////////////////////////////////
#define PI 3.14159265359

///////////////////////////////////////////////////////////////////////////////
// Input varyings from vertex shader
///////////////////////////////////////////////////////////////////////////////
in vec2 texCoord;
in vec3 viewSpaceNormal;
in vec3 viewSpacePosition;

///////////////////////////////////////////////////////////////////////////////
// Input uniform variables
///////////////////////////////////////////////////////////////////////////////
uniform mat4 viewInverse;
uniform vec3 viewSpaceLightPosition;

///////////////////////////////////////////////////////////////////////////////
// Output color
///////////////////////////////////////////////////////////////////////////////
layout(location = 0) out vec4 fragmentColor;

// Light Matrix
uniform mat4 lightMatrix;
in vec4 shadowMapCoord;
#if SOLUTION_USE_BUILTIN_SHADOW_TEST
layout(binding = 10) uniform sampler2DShadow shadowMapTex;
#else  // USE_BUILTIN_SHADOW_TEST
layout(binding = 10) uniform sampler2D shadowMapTex;
#endif // ~ USE_BUILTIN_SHADOW_TEST

uniform int useSpotLight;
uniform int useSoftFalloff;
uniform vec3 viewSpaceLightDir;
uniform float spotInnerAngle;
uniform float spotOuterAngle;


vec3 calculateDirectIllumiunation(vec3 wo, vec3 n, vec3 base_color)
{
	// return vec3(1.f);
	vec3 direct_illum = base_color;

	vec4 shadowMapCoord = lightMatrix * vec4(viewSpacePosition, 1.f);

	float depth = texture(shadowMapTex, shadowMapCoord.xy / shadowMapCoord.w).x;
	float visibility = (depth >= (shadowMapCoord.z / shadowMapCoord.w)) ? 1.0 : 0.0;

	///////////////////////////////////////////////////////////////////////////
	// Task 1.2 - Calculate the radiance Li from the light, and the direction
	//            to the light. If the light is backfacing the triangle,
	//            return vec3(0);
	///////////////////////////////////////////////////////////////////////////
    const float distants_to_light = length(viewSpaceLightPosition - viewSpacePosition);
	vec3 Li = point_light_intensity_multiplier * point_light_color * 1/(distants_to_light * distants_to_light);
	vec3 wi = normalize(viewSpaceLightPosition-viewSpacePosition);
	if(dot(wi, n) <= 0.0)
		return vec3(0.0);

	///////////////////////////////////////////////////////////////////////////
	// Task 1.3 - Calculate the diffuse term and return that as the result
	vec3 diffuse_term = base_color * (1.0/PI) * dot(n, wi) * Li;
	///////////////////////////////////////////////////////////////////////////

	///////////////////////////////////////////////////////////////////////////
	// Task 2 - Calculate the Torrance Sparrow BRDF and return the light
	//          reflected from that instead
	///////////////////////////////////////////////////////////////////////////

	vec3 wh = normalize(wi + wo);
	float ndotwh = max(0.0001, dot(n, wh));
	float ndotwo = max(0.0001, dot(n, wo));
	float wodotwh = max(0.0001, dot(wo, wh));
	float whdotwi = max(0.0001, dot(wh, wi));
	float ndotwi = max(0.0001, dot(n, wi));
	float D = ((material_shininess+2.0)/(2.0*PI)) * pow(ndotwh, material_shininess);
	float F = material_fresnel + (1.0-material_fresnel)*pow((1.0 - whdotwi), 5.0); 
	float G = min(1.0, min(2.0*(ndotwh*ndotwo/wodotwh), 2.0*(ndotwh*ndotwi/wodotwh)));
	float brdf = (F * D * G)/(4*ndotwo*ndotwi);

	//return brdf * dot(n, wi) * Li;  

	//return vec3(D);
	//return vec3(G);
	//return vec3(F);

	//return diffuse_term;

	///////////////////////////////////////////////////////////////////////////
	// Task 3 - Make your shader respect the parameters of our material model.
	///////////////////////////////////////////////////////////////////////////

	vec3 dielectric_term = brdf * (ndotwi*Li) + (1.0-F) * diffuse_term;
	vec3 metal_term = brdf * base_color * (ndotwi*Li);
	direct_illum = material_metalness * metal_term + (1.0-material_metalness) * dielectric_term;
	return visibility * direct_illum;
}

vec3 calculateIndirectIllumination(vec3 wo, vec3 n, vec3 base_color)
{
	// return vec3(0.0);
	vec3 indirect_illum = vec3(0.f);
	///////////////////////////////////////////////////////////////////////////
	// Task 5 - Lookup the irradiance from the irradiance map and calculate
	//          the diffuse reflection
	///////////////////////////////////////////////////////////////////////////

	vec3 world_normal = vec3(viewInverse * vec4(n, 0.0));
	float theta = acos(max(-1.0f, min(1.0f, world_normal.y)));
	float phi = atan(world_normal.z, world_normal.x);
	if(phi < 0.0f)
		phi = phi + 2.0f * PI;
	vec2 lookup = vec2(phi / (2.0 * PI), 1 - theta / PI);
	vec3 Li = environment_multiplier * texture(irradianceMap, lookup).rgb;
	vec3 diffuse_term = base_color * (1.0 / PI) * Li;
	indirect_illum = diffuse_term;

	///////////////////////////////////////////////////////////////////////////
	// Task 6 - Look up in the reflection map from the perfect specular
	//          direction and calculate the dielectric and metal terms.
	///////////////////////////////////////////////////////////////////////////

	vec3 wi = normalize(reflect(-wo, n));
	vec3 wr = normalize(vec3(viewInverse * vec4(wi, 0.0)));
	theta = acos(max(-1.0f, min(1.0f, wr.y)));
	phi = atan(wr.z, wr.x);
	if(phi < 0.0f)
		phi = phi + 2.0f * PI;
	lookup = vec2(phi / (2.0 * PI), 1 - theta / PI);

	float roughness = sqrt(sqrt(2.0/(material_shininess)));
	Li = environment_multiplier * textureLod(reflectionMap, lookup, roughness * 7.0).rgb;

	vec3 wh = normalize(wi + wo);
	float whdotwi = max(0.0001, dot(wh, wi));
	float F = material_fresnel + (1.0-material_fresnel)*pow((1.0 - whdotwi), 5.0); 

	vec3 dielectric_term = F*Li + (1.0-F)*diffuse_term;
	vec3 metal_term = F * base_color * Li;

	indirect_illum = material_metalness * metal_term + (1.0-material_metalness) * dielectric_term;

	return indirect_illum;
}

void main()
{
	float visibility = 1.0;
	float attenuation = 1.0;


	vec3 wo = -normalize(viewSpacePosition);
	vec3 n = normalize(viewSpaceNormal);

	vec3 base_color = material_color;
	if(has_color_texture == 1)
	{
		base_color = texture(colorMap, texCoord).rgb;
	}

	// Direct illumination
	vec3 direct_illumination_term = visibility * calculateDirectIllumiunation(wo, n, base_color);

	// Indirect illumination
	vec3 indirect_illumination_term = calculateIndirectIllumination(wo, n, base_color);

	///////////////////////////////////////////////////////////////////////////
	// Add emissive term. If emissive texture exists, sample this term.
	///////////////////////////////////////////////////////////////////////////
	vec3 emission_term = material_emission;
	if(has_emission_texture == 1)
	{
		emission_term = texture(emissiveMap, texCoord).rgb;
	}

	vec3 shading = direct_illumination_term + indirect_illumination_term + emission_term;

	fragmentColor = vec4(shading, 1.0);
	return;
}
