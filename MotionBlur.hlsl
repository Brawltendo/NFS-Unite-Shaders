// Use this filename with 3DMigoto: 44aa427c5f4281a7-ps_replace.txt
// Motion blur shader

// A note about textures in this shader: 
// Since Heat's motion blur shader (also shared with Payback) doesn't use any texture samplers
// unlike the shader found in Rivals and NFS15, we have to multiply the texcoords by the screen pixel size
// to convert the UV coords into screen coords
Texture2D<float4> depthTexture : register(t0);
Texture2D<float4> mainTexture : register(t1);
Texture2D<float4> velocityTexture : register(t2);
Texture2D<float4> velocityTileTexture : register(t3);
Texture2D<float4> t4 : register(t4);


// Contains all external constants for this shader
// This includes default values and values that are passed into the shader
cbuffer cb0 : register(b0)
{
	uint maxSamples; // cb0[0].x
	uint unk1; // cb0[0].y
	int blurVisualizationMode; // cb0[0].z
	float unk3; // cb0[0].w
	float unk4; // cb0[1].x
	float unk5; // cb0[1].y
	int unk6; // cb0[1].z
	int unk7; // cb0[1].w
	float2 velocityPixelSize; // cb0[2].xy
	float2 velocityTilePixelSize; // cb0[2].zw
	float unk9; // cb0[3].x
	float unk10; // cb0[3].y
	float2 screenPixelSize; // cb0[3].zw
}


void main(
	float4 screenPos : SV_Position0,
	out float4 outColor : SV_Target0)
{
	// default value in NFS15 is 0.1, looks good like that so we can just leave it there
	// we won't be able to control this value from a shader param, but no one's really gonna tweak it anyway
	const float velScale = 0.1;

	// default value in NFS15 is 10
	const float maxVel = 10.0;

	// default value in NFS15 is 5
	const float maxDepth = 5.0;

	// default value in NFS15 is 0.05
	// setting it to 0.1 or 0.15 mostly alleviates the issue where the blur is partially cut off when looking back
	const float minDepthCheck = 0.15;

	// Heat's motion blur uses 24 samples max, but in 2015 it's set to a max of 20 and looks better
	// we'll set it to 20 since the visual impact is very minimal and performance will be slightly better
	const float numSamples = 20.0;

	const float noiseScale = 1.0;

	float2 invPixelSize = 1.0 / screenPixelSize;
	float2 texCoords = invPixelSize.xy * screenPos.xy;

	// scale velocity and convert from clip space to screen space
	float2 screenSpaceVel = velocityTexture.Load(int3(screenPos.xy, 0)).xy * float2(-velScale, velScale);
	
	// scale the velocity length by the max motion blur velocity so that we can clamp the final velocity
	float velLengthMax = length(screenSpaceVel) * maxVel;
	if (1.0 < velLengthMax) 
	  screenSpaceVel /= velLengthMax;

	float3 blurColor = mainTexture.Load(int3(screenPos.xy, 0)).xyz;
	float depthThresh = min(maxDepth, depthTexture.Load(int3(screenPos.xy, 0)).x - minDepthCheck);
	float sampleCount = max(1, length(screenSpaceVel / invPixelSize.xy));
	sampleCount = 1.0 < sampleCount ? (ceil(sampleCount * 0.25) * 4.0) : 1.0;
	sampleCount = min(numSamples, sampleCount);
	screenSpaceVel *= 1.0 / sampleCount;

	float2 uvNoise = float2(0.0, 0.0);
	// generate UV noise
	{
		uint2 pos = uint2(screenPos.xy) + unk6;
		pos = mad(pos.xx, uint2(0xf4559d5, 0x2e48eddb), pos.yy);
		pos *= 1025u;
		pos ^= pos >> 6u;
		pos *= 9u;
		pos &= 127u;
		uvNoise = -((pos.xy / 127.0 - 0.5) * 0.75);
	}

	// multiply velocity by noise and add to texcoords to break up sampling artifacts
	texCoords += screenSpaceVel * uvNoise;
	float val = 1.0;
	float i = 1.0;

	// I would make this a for loop but the game crashed when I tried it, so it'll remain a while loop for now
	[loop]
	while (true)
	{
		if (i >= sampleCount) break;

		[unroll]
		for (int k = 0; k < 4; k++)
		{
			texCoords += screenSpaceVel;
			float2 texPos = texCoords * screenPixelSize.xy;
			float3 col = mainTexture.Load(int3(texPos, 0)).xyz;
			float depth = depthTexture.Load(int3(texPos, 0)).x;
			float shouldAddColor = depthThresh < depth;
			blurColor += col * shouldAddColor;
			val += shouldAddColor;
			i++;
		}
	}
	outColor.xyz = blurColor / val;
	outColor.w = 1.0;
}