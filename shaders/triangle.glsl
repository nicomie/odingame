
#type vertex
#version 330 core
layout (location = 0) in vec3 aPos;

void main()
    gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}

#type fragment
#version 330 core
in vec4 v_color;
out vec4 o_color;

void main() {
	o_color = v_color;
}
