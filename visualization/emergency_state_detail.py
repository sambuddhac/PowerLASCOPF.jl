from manim import *

class EmergencyStateDetail(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        YELLOW_3B1B = "#FFFF00"
        ORANGE_3B1B = "#FFA500"
        
        # Title
        title = Text("Emergency State Thermal Limit Analysis", font_size=32, color=BLUE_3B1B)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # Main Emergency State Container
        emergency_container = RoundedRectangle(
            width=10, height=5.5,
            corner_radius=0.3,
            color=RED_3B1B,
            fill_opacity=0.15,
            stroke_width=4
        )
        emergency_container.move_to(DOWN * 0.3)
        
        emergency_title = Text("Emergency State of Operation", font_size=24, color=RED_3B1B, weight=BOLD)
        emergency_title.next_to(emergency_container, UP, buff=0.2)
        
        self.play(
            Create(emergency_container),
            Flash(emergency_container, color=RED_3B1B, flash_radius=2.0),
            run_time=1.2
        )
        self.play(Write(emergency_title), run_time=0.8)
        self.wait(0.5)
        
        # Long-Term Rating Violation (Left side)
        long_term_box = RoundedRectangle(
            width=4, height=3.5,
            corner_radius=0.2,
            color=ORANGE_3B1B,
            fill_opacity=0.25,
            stroke_width=3
        )
        long_term_box.shift(LEFT * 2.5 + DOWN * 0.5)
        
        long_term_label = Text("Violation of\nLong-Term\nRatings", font_size=18, color=ORANGE_3B1B, weight=BOLD)
        long_term_label.move_to(long_term_box.get_center() + UP * 0.8)
        
        # Animate long-term violation
        lt_outline = long_term_box.copy().set_fill(opacity=0).set_stroke(ORANGE_3B1B, width=6)
        self.play(Create(lt_outline), run_time=0.6)
        self.play(
            FadeOut(lt_outline),
            FadeIn(long_term_box),
            Flash(long_term_box, color=ORANGE_3B1B, flash_radius=1.2),
            run_time=0.8
        )
        self.play(Write(long_term_label), run_time=0.7)
        
        # Long-term rating details
        lt_temp = MathTex(r"\psi_{T_r} > \psi_{T_r}^{long}", font_size=28, color=ORANGE_3B1B)
        lt_temp.move_to(long_term_box.get_center() + DOWN * 0.2)
        
        lt_time = Text("Time: t > ΓRN D", font_size=14, color=ORANGE_3B1B)
        lt_time.move_to(long_term_box.get_center() + DOWN * 1.0)
        
        self.play(Write(lt_temp), run_time=0.8)
        self.play(FadeIn(lt_time, scale=0.8), run_time=0.6)
        
        # Add icon/warning
        lt_warning = Text("⚠", font_size=40, color=ORANGE_3B1B)
        lt_warning.next_to(long_term_box, DOWN, buff=0.3)
        self.play(FadeIn(lt_warning, scale=1.5), run_time=0.5)
        
        lt_desc = Text("Sustained\noverload", font_size=12, color=ORANGE_3B1B)
        lt_desc.next_to(lt_warning, DOWN, buff=0.15)
        self.play(Write(lt_desc), run_time=0.5)
        
        self.wait(0.5)
        
        # Short-Term Rating Violation (Right side)
        short_term_box = RoundedRectangle(
            width=4, height=3.5,
            corner_radius=0.2,
            color=RED_3B1B,
            fill_opacity=0.3,
            stroke_width=3
        )
        short_term_box.shift(RIGHT * 2.5 + DOWN * 0.5)
        
        short_term_label = Text("Violation of\nShort-Term\nRatings", font_size=18, color=RED_3B1B, weight=BOLD)
        short_term_label.move_to(short_term_box.get_center() + UP * 0.8)
        
        # Animate short-term violation
        st_outline = short_term_box.copy().set_fill(opacity=0).set_stroke(RED_3B1B, width=6)
        self.play(Create(st_outline), run_time=0.6)
        self.play(
            FadeOut(st_outline),
            FadeIn(short_term_box),
            Flash(short_term_box, color=RED_3B1B, flash_radius=1.2),
            run_time=0.8
        )
        self.play(Write(short_term_label), run_time=0.7)
        
        # Short-term rating details
        st_temp = MathTex(r"\psi_{T_r} > \psi_{T_r}^{short}", font_size=28, color=RED_3B1B)
        st_temp.move_to(short_term_box.get_center() + DOWN * 0.2)
        
        st_time = Text("Time: 0 < t ≤ ΓRND", font_size=14, color=RED_3B1B)
        st_time.move_to(short_term_box.get_center() + DOWN * 1.0)
        
        self.play(Write(st_temp), run_time=0.8)
        self.play(FadeIn(st_time, scale=0.8), run_time=0.6)
        
        # Add critical icon
        st_critical = Text("🔥", font_size=40, color=RED_3B1B)
        st_critical.next_to(short_term_box, DOWN, buff=0.3)
        self.play(FadeIn(st_critical, scale=1.5), run_time=0.5)
        
        st_desc = Text("Critical\nimmediate risk", font_size=12, color=RED_3B1B)
        st_desc.next_to(st_critical, DOWN, buff=0.15)
        self.play(Write(st_desc), run_time=0.5)
        
        self.wait(0.5)
        
        # Arrow showing progression from short to long
        progression_arrow = Arrow(
            start=short_term_box.get_left(),
            end=long_term_box.get_right(),
            color=YELLOW_3B1B,
            stroke_width=4,
            tip_length=0.3
        )
        
        progression_label = Text("Time\nProgression", font_size=14, color=YELLOW_3B1B, weight=BOLD)
        progression_label.next_to(progression_arrow, UP, buff=0.2)
        
        self.play(Create(progression_arrow), run_time=1)
        self.play(Write(progression_label), run_time=0.6)
        
        self.wait(0.5)
        
        # Temperature evolution graph (small inset)
        graph_axes = Axes(
            x_range=[0, 10, 2],
            y_range=[0, 150, 50],
            x_length=3,
            y_length=1.5,
            axis_config={"color": WHITE, "stroke_width": 2, "include_tip": False},
            x_axis_config={"numbers_to_include": []},
            y_axis_config={"numbers_to_include": []}
        )
        graph_axes.to_corner(UL, buff=0.8)
        
        # Temperature curve
        temp_curve = graph_axes.plot(
            lambda x: 50 + 80 * (1 - np.exp(-0.5 * x)),
            x_range=[0, 10],
            color=RED_3B1B,
            stroke_width=3
        )
        
        # Limit lines
        short_limit = DashedLine(
            start=graph_axes.c2p(0, 120),
            end=graph_axes.c2p(10, 120),
            color=RED_3B1B,
            stroke_width=2
        )
        
        long_limit = DashedLine(
            start=graph_axes.c2p(0, 90),
            end=graph_axes.c2p(10, 90),
            color=ORANGE_3B1B,
            stroke_width=2
        )
        
        graph_title = Text("Temperature Evolution", font_size=12, color=BLUE_3B1B, weight=BOLD)
        graph_title.next_to(graph_axes, UP, buff=0.15)
        
        x_label = Text("Time", font_size=10, color=WHITE)
        x_label.next_to(graph_axes, DOWN, buff=0.1)
        
        y_label = Text("ψ", font_size=12, color=WHITE)
        y_label.next_to(graph_axes, LEFT, buff=0.1)
        
        # Animate graph
        self.play(
            Create(graph_axes),
            Write(graph_title),
            Write(x_label),
            Write(y_label),
            run_time=0.8
        )
        self.play(
            Create(short_limit),
            Create(long_limit),
            run_time=0.6
        )
        
        short_label_g = Text("Short", font_size=8, color=RED_3B1B)
        short_label_g.next_to(short_limit, RIGHT, buff=0.05)
        
        long_label_g = Text("Long", font_size=8, color=ORANGE_3B1B)
        long_label_g.next_to(long_limit, RIGHT, buff=0.05)
        
        self.play(
            Write(short_label_g),
            Write(long_label_g),
            run_time=0.5
        )
        
        self.play(Create(temp_curve), run_time=2, rate_func=linear)
        
        self.wait(0.5)

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # Equation constraint box at bottom
        constraint_box = Rectangle(
            width=11, height=0.8,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=2
        )
        constraint_box.to_edge(DOWN, buff=0.3)
        
        constraint_eq = MathTex(
            r"E_{\Gamma}^{(\omega)}[\psi_{\text{init}}] + (1-E_{\Gamma}^{(\omega)})[\psi_{\text{amb}}] + \frac{\alpha'}{\beta'}[...] < \psi_{T_r}^{\max}",
            font_size=20,
            color=BLUE_3B1B
        )
        constraint_eq.move_to(constraint_box)
        
        self.play(
            Create(constraint_box),
            Write(constraint_eq),
            run_time=1
        )
        
        constraint_label = Text("Thermal Constraint (Eqn 6.6a)", font_size=11, color=BLUE_3B1B)
        constraint_label.next_to(constraint_box, UP, buff=0.1)
        self.play(Write(constraint_label), run_time=0.6)
        
        self.wait(2)