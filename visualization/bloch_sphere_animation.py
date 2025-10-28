from manim import *

class BlochSphere(ThreeDScene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        PURPLE_3B1B = "#9370DB"
        ORANGE = "#FFA500"  # Lighter orange
        
        # Title
        title = Text("The Bloch Sphere", font_size=40, color=BLUE_3B1B)
        title.to_edge(UP)
        self.add_fixed_in_frame_mobjects(title)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # Set up 3D scene
        self.set_camera_orientation(phi=75 * DEGREES, theta=-45 * DEGREES)
        
        # Create the sphere
        sphere = Sphere(radius=2, resolution=(20, 20))
        sphere.set_color(BLUE_3B1B)
        sphere.set_opacity(0.15)
        sphere.set_stroke(BLUE_3B1B, width=0.5)
        
        self.play(Create(sphere), run_time=1.5)
        self.wait(0.5)
        
        # Create coordinate axes
        axes = ThreeDAxes(
            x_range=[-2.5, 2.5, 1],
            y_range=[-2.5, 2.5, 1],
            z_range=[-2.5, 2.5, 1],
            x_length=5,
            y_length=5,
            z_length=5,
            axis_config={
                "color": WHITE,
                "stroke_width": 2,
                "include_tip": True,
                "tip_length": 0.2
            }
        )
        
        self.play(Create(axes), run_time=1)
        self.wait(0.3)
        
        # Axis labels
        x_label = MathTex("X", font_size=32, color=RED_3B1B)
        x_label.rotate(PI/2, axis=RIGHT)
        x_label.next_to(axes.x_axis.get_end(), RIGHT, buff=0.2)
        
        y_label = MathTex("Y", font_size=32, color=GREEN_3B1B)
        y_label.rotate(PI/2, axis=RIGHT)
        y_label.next_to(axes.y_axis.get_end(), UP, buff=0.2)
        
        z_label = MathTex("Z", font_size=32, color=BLUE_3B1B)
        z_label.rotate(PI/2, axis=RIGHT)
        z_label.next_to(axes.z_axis.get_end(), OUT, buff=0.2)
        
        self.play(
            Write(x_label),
            Write(y_label),
            Write(z_label),
            run_time=0.8
        )
        self.wait(0.5)
        
        # |0⟩ state at north pole
        zero_ket_pos = axes.c2p(0, 0, 2)
        zero_dot = Sphere(radius=0.15, color=YELLOW_3B1B)
        zero_dot.move_to(zero_ket_pos)
        
        zero_label = MathTex(r"|0\rangle", font_size=36, color=YELLOW_3B1B)
        zero_label.rotate(PI/2, axis=RIGHT)
        zero_label.next_to(zero_ket_pos, OUT, buff=0.3)
        
        self.play(
            FadeIn(zero_dot, scale=2),
            run_time=0.8
        )
        self.play(Write(zero_label), run_time=0.6)
        self.wait(0.5)
        
        # |1⟩ state at south pole
        one_ket_pos = axes.c2p(0, 0, -2)
        one_dot = Sphere(radius=0.15, color=RED_3B1B)
        one_dot.move_to(one_ket_pos)
        
        one_label = MathTex(r"|1\rangle", font_size=36, color=RED_3B1B)
        one_label.rotate(PI/2, axis=RIGHT)
        one_label.next_to(one_ket_pos, OUT, buff=0.3)
        
        self.play(
            FadeIn(one_dot, scale=2),
            run_time=0.8
        )
        self.play(Write(one_label), run_time=0.6)
        self.wait(0.5)
        
        # |+⟩ state on X axis
        plus_ket_pos = axes.c2p(2, 0, 0)
        plus_dot = Sphere(radius=0.12, color=GREEN_3B1B)
        plus_dot.move_to(plus_ket_pos)
        
        plus_label = MathTex(r"|+\rangle", font_size=28, color=GREEN_3B1B)
        plus_label.rotate(PI/2, axis=RIGHT)
        plus_label.next_to(plus_ket_pos, RIGHT, buff=0.2)
        
        self.play(FadeIn(plus_dot, scale=1.5), run_time=0.6)
        self.play(Write(plus_label), run_time=0.5)
        
        # |-⟩ state on -X axis
        minus_ket_pos = axes.c2p(-2, 0, 0)
        minus_dot = Sphere(radius=0.12, color=PURPLE_3B1B)
        minus_dot.move_to(minus_ket_pos)
        
        minus_label = MathTex(r"|-\rangle", font_size=28, color=PURPLE_3B1B)
        minus_label.rotate(PI/2, axis=RIGHT)
        minus_label.next_to(minus_ket_pos, LEFT, buff=0.2)
        
        self.play(FadeIn(minus_dot, scale=1.5), run_time=0.6)
        self.play(Write(minus_label), run_time=0.5)
        
        self.wait(0.5)
        
        # General state vector (animated)
        theta = 60 * DEGREES
        phi = 45 * DEGREES
        
        state_x = 2 * np.sin(theta) * np.cos(phi)
        state_y = 2 * np.sin(theta) * np.sin(phi)
        state_z = 2 * np.cos(theta)
        
        state_pos = axes.c2p(state_x, state_y, state_z)
        
        # State vector arrow
        state_arrow = Arrow3D(
            start=axes.c2p(0, 0, 0),
            end=state_pos,
            color=YELLOW_3B1B,
            thickness=0.03,
            height=0.3,
            base_radius=0.08
        )
        
        state_dot = Sphere(radius=0.18, color=YELLOW_3B1B)
        state_dot.move_to(state_pos)
        
        state_label = MathTex(r"|\psi\rangle", font_size=36, color=YELLOW_3B1B)
        state_label.rotate(PI/2, axis=RIGHT)
        state_label.next_to(state_pos, OUT + RIGHT, buff=0.3)
        
        # Animate state vector appearing (using Create instead of GrowArrow for 3D)
        self.play(
            Create(state_arrow),
            run_time=1
        )
        self.play(
            FadeIn(state_dot, scale=2),
            Write(state_label),
            run_time=0.8
        )
        self.wait(0.5)
        
        # Rotate camera to show 3D structure
        self.begin_ambient_camera_rotation(rate=0.15)
        self.wait(3)
        self.stop_ambient_camera_rotation()
        
        self.move_camera(phi=70 * DEGREES, theta=-60 * DEGREES, run_time=2)
        self.wait(0.5)
        
        # Show theta and phi angles
        # Theta arc (from Z-axis)
        theta_arc = Arc(
            radius=0.8,
            start_angle=PI/2,
            angle=-theta,
            color=ORANGE
        )
        theta_arc.rotate(PI/2, axis=UP)
        theta_arc.rotate(phi, axis=OUT)
        theta_arc.shift(axes.c2p(0, 0, 0))
        
        theta_label = MathTex(r"\theta", font_size=28, color=ORANGE)
        theta_label.rotate(PI/2, axis=RIGHT)
        theta_label.move_to(axes.c2p(0.3, 0.3, 1.2))
        
        # Phi arc (in XY plane)
        phi_arc = Arc(
            radius=1.2,
            start_angle=0,
            angle=phi,
            color=GREEN_3B1B
        )
        phi_arc.shift(axes.c2p(0, 0, 0))
        
        phi_label = MathTex(r"\phi", font_size=28, color=GREEN_3B1B)
        phi_label.rotate(PI/2, axis=RIGHT)
        phi_label.move_to(axes.c2p(0.8, 0.4, 0))
        
        self.play(
            Create(theta_arc),
            Write(theta_label),
            run_time=0.8
        )
        self.play(
            Create(phi_arc),
            Write(phi_label),
            run_time=0.8
        )
        self.wait(0.5)
        
        # Add equation box (fixed to frame)
        equation_box = Rectangle(
            width=6, height=1.2,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=2
        )
        equation_box.to_edge(DOWN, buff=0.5)
        
        state_equation = MathTex(
            r"|\psi\rangle = \cos\frac{\theta}{2}|0\rangle + e^{i\phi}\sin\frac{\theta}{2}|1\rangle",
            font_size=28,
            color=BLUE_3B1B
        )
        state_equation.move_to(equation_box)
        
        self.add_fixed_in_frame_mobjects(equation_box, state_equation)
        self.play(
            Create(equation_box),
            Write(state_equation),
            run_time=1.2
        )
        self.wait(1)
        
        # Animate state evolution
        self.play(
            Rotate(state_arrow, angle=PI, axis=RIGHT, about_point=axes.c2p(0, 0, 0)),
            Rotate(state_dot, angle=PI, axis=RIGHT, about_point=axes.c2p(0, 0, 0)),
            Rotate(state_label, angle=PI, axis=RIGHT, about_point=axes.c2p(0, 0, 0)),
            run_time=3,
            rate_func=smooth
        )
        
        self.wait(0.5)
        
        # Rotate around Z axis
        self.play(
            Rotate(state_arrow, angle=2*PI, axis=OUT, about_point=axes.c2p(0, 0, 0)),
            Rotate(state_dot, angle=2*PI, axis=OUT, about_point=axes.c2p(0, 0, 0)),
            Rotate(state_label, angle=2*PI, axis=OUT, about_point=axes.c2p(0, 0, 0)),
            run_time=4,
            rate_func=linear
        )
        
        self.wait(1)
        
        # Final camera rotation
        self.begin_ambient_camera_rotation(rate=0.1)
        self.wait(5)
        self.stop_ambient_camera_rotation()
        
        self.wait(2)