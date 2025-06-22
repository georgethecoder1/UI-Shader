// A shader that's responsible for all UI components added on top of the UI element


// WINDOW UNIFORMS
uniform vec2 windowSize;  // SIZE OF THE CURRENT UI ELEMENT
uniform vec4 windowColor; // COLOR OF THE CURRENT UI ELEMENT

// CORNER UNIFORMS
uniform bool enabledCorner; // INDICATOR WHENEVER ROUNDED CORNERS SHOULD BE ENABLED FOR THE CURRENT UI ELEMENT
uniform float cornerRadius;  // CORNER RADIUS OF THE CURRENT UI ELEMENT


// GRADIENT UNIFORMS
uniform bool enabledGradient; // INDICATOR WHENEVER GRADIENT SHOULD BE ENABLED FOR THE CURRENT UI ELEMENT
uniform vec4 gradientColors[24]; // GRADIENT COLORS OF THE CURRENT UI ELEMENT
uniform float gradientNodes[24]; // GRADIENT NODES (POSITIONS) OF THE CURRENT UI ELEMENT
uniform float gradientLength; // GRADIENT LENGTH OF THE CURRENT UI ELEMENT
uniform float gradientRotation; // GRADIENT ROTATION OF THE CURRENT UI ELEMENT


// OUTLINE UNIFORMS
uniform bool enabledOutline; // INDICATOR WHENEVER OUTLINE SHOULD BE ENABLED FOR THE CURRENT UI ELEMENT
uniform vec4 outlineColor; // OUTLINE (BORDER) COLOR OF THE CURRENT UI ELEMENT
uniform float outlineSize; // OUTLINE (BORDER) SIZE OF THE CURRENT UI ELEMENT





// SIGNED DISTANCE FIELD FUNCTION
float SignedDistanceFields(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}



// VERTEX SHADER

#ifdef VERTEX

vec4 position(mat4 transformProjection, vec4 vertexPosition) 
{
    return transformProjection * vertexPosition;
}

#endif


// PIXEL SHADER

#ifdef PIXEL

vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) 
{
    vec2 windowCoordinates = screenCoordinates;
    vec2 windowNormalizedCoordinates = windowCoordinates / windowSize;

    vec4 expectedColor = Texel(texture, textureCoordinates) * windowColor;

    vec2 halfWindowSize = windowSize * 0.5;

    vec2 relativeWindowCenterUVCoord = windowCoordinates - halfWindowSize;
    vec2 normalizedRelativeWindowCenterUVCoord = windowNormalizedCoordinates - 0.5;

    float cornerOutlineSizeDifference = max(0, cornerRadius - outlineSize);

    float externalWindowDistance = SignedDistanceFields(relativeWindowCenterUVCoord, halfWindowSize, cornerRadius);
    float internalWindowDistance = SignedDistanceFields(relativeWindowCenterUVCoord, halfWindowSize - outlineSize, cornerOutlineSizeDifference);

    bool shouldApplyCorner = enabledCorner && externalWindowDistance > 0.0;
    bool shouldApplyOutline = enabledOutline && externalWindowDistance < 0 && internalWindowDistance > 0.0;
    bool shouldApplyGradient = enabledGradient && internalWindowDistance < 0.0;

    float gradientCosineAngle = cos(gradientRotation);
    float gradientSineAngle = sin(gradientRotation);

    float absoluteCosineAngle = abs(gradientCosineAngle);
    float absoluteSineAngle = abs(gradientSineAngle);

    mat2 gradientRotationMatrix = mat2(gradientCosineAngle, -gradientSineAngle, gradientSineAngle, gradientCosineAngle);
    vec2 rotatedWindowCenterUVCoord = gradientRotationMatrix * relativeWindowCenterUVCoord;

    vec2 realInternalWindowDimensions = windowSize - 2.0 * outlineSize;
    vec2 realInternalHalfWindowDimensions = realInternalWindowDimensions * 0.5;

    float internalRoundedRectDistance = SignedDistanceFields(rotatedWindowCenterUVCoord, realInternalHalfWindowDimensions - cornerRadius, cornerRadius);
    float uvOffsetFactor = 1.0 - clamp(abs(internalRoundedRectDistance) * max(windowSize.x, windowSize.y) + cornerRadius, 0.0, 1.0);

    float currentGradientProgress = (rotatedWindowCenterUVCoord.x / (sqrt(min(realInternalHalfWindowDimensions.x, realInternalHalfWindowDimensions.y) / max(realInternalHalfWindowDimensions.x, realInternalHalfWindowDimensions.y)) / max(absoluteCosineAngle, absoluteSineAngle)) + max(realInternalHalfWindowDimensions.x * absoluteCosineAngle, realInternalHalfWindowDimensions.y * absoluteSineAngle)) / max(realInternalWindowDimensions.x * absoluteCosineAngle, realInternalWindowDimensions.y * absoluteSineAngle);
    currentGradientProgress = clamp(currentGradientProgress, 0.0, 1.0);

    float uvDistanceFromCenter = currentGradientProgress - 0.5;
    float uvCenterDisplacement = uvDistanceFromCenter * uvOffsetFactor;

    float adjustedGradientProgress = currentGradientProgress - uvCenterDisplacement;

    // REMOVES (HIDES) UNNECESSARY PIXELS TO APPLY ROUNDED CORNERS
    if (shouldApplyCorner) 
    {
        expectedColor.a = 0.0;
    }
    
    // APPLIES OUTLINE (BORDER) COLOR
    else if (shouldApplyOutline) 
    {
        return outlineColor;
    }
    
    // APLIES GRADIENT COLOR
    else if (shouldApplyGradient) 
    {
        for (int i = 0; i < gradientLength - 1; i++) 
        {
            vec4 startGradientColor = gradientColors[i];
            vec4 endGradientColor = gradientColors[i + 1];

            float startGradientNode = gradientNodes[i];
            float endGradientNode = gradientNodes[i + 1];

            bool windowCoordWithinGradientRange = adjustedGradientProgress >= startGradientNode && adjustedGradientProgress <= endGradientNode;

            if (windowCoordWithinGradientRange) 
            {
                float gradientLerpingTime = (adjustedGradientProgress - startGradientNode) / (endGradientNode - startGradientNode);
                return mix(startGradientColor, endGradientColor, gradientLerpingTime);
            }
        }
    }
    
    return expectedColor;
}

#endif