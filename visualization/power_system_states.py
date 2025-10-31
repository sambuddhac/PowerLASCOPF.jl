from manim import *

class PowerSystemStates(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        YELLOW_3B1B = "#FFFF00"
        ORANGE_3B1B = "#FFA500"
        
        # Title
        title = Text("Power System Operational States", font_size=36, color=BLUE_3B1B)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # NORMAL STATE (main container)
        normal_box = RoundedRectangle(
            width=8, height=5,
            corner_radius=0.3,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=4
        )
        normal_box.move_to(ORIGIN)
        
        normal_label = Text("Normal State of Operation", font_size=24, color=BLUE_3B1B, weight=BOLD)
        normal_label.next_to(normal_box, UP, buff=0.2)
        
        self.play(Create(normal_box), run_time=1)
        self.play(Write(normal_label), run_time=0.8)
        self.wait(0.5)
        
        # SECURE STATE (within Normal State)
        secure_circle = Circle(
            radius=1.5,
            color=GREEN_3B1B,
            fill_opacity=0.3,
            stroke_width=3
        )
        secure_circle.shift(LEFT * 2 + UP * 0.5)
        
        secure_label = Text("Secure\nState", font_size=20, color=GREEN_3B1B, weight=BOLD)
        secure_label.move_to(secure_circle)
        
        # Create with outline effect
        secure_outline = secure_circle.copy().set_fill(opacity=0).set_stroke(GREEN_3B1B, width=5)
        self.play(Create(secure_outline), run_time=0.6)
        self.play(
            FadeOut(secure_outline),
            FadeIn(secure_circle),
            Flash(secure_circle, color=GREEN_3B1B, flash_radius=1.0),
            run_time=0.8
        )
        self.play(Write(secure_label), run_time=0.6)
        self.wait(0.5)
        
        # Add checkmark for secure state
        checkmark = Text("✓", font_size=48, color=GREEN_3B1B, weight=BOLD)
        checkmark.next_to(secure_circle, DOWN, buff=0.3)
        self.play(FadeIn(checkmark, scale=1.5), run_time=0.5)
        
        # Description for secure state
        secure_desc = Text(
            "All constraints satisfied\n(N-1) Security maintained",
            font_size=12,
            color=GREEN_3B1B
        )
        secure_desc.next_to(checkmark, DOWN, buff=0.2)
        self.play(FadeIn(secure_desc, scale=0.8), run_time=0.6)
        
        self.wait(0.5)
        
        # INSECURE STATE (within Normal State)
        insecure_circle = Circle(
            radius=1.5,
            color=ORANGE_3B1B,
            fill_opacity=0.3,
            stroke_width=3
        )
        insecure_circle.shift(RIGHT * 2 + UP * 0.5)
        
        insecure_label = Text("Insecure\nState", font_size=20, color=ORANGE_3B1B, weight=BOLD)
        insecure_label.move_to(insecure_circle)
        
        # Create with outline effect
        insecure_outline = insecure_circle.copy().set_fill(opacity=0).set_stroke(ORANGE_3B1B, width=5)
        self.play(Create(insecure_outline), run_time=0.6)
        self.play(
            FadeOut(insecure_outline),
            FadeIn(insecure_circle),
            Flash(insecure_circle, color=ORANGE_3B1B, flash_radius=1.0),
            run_time=0.8
        )
        self.play(Write(insecure_label), run_time=0.6)
        self.wait(0.5)
        
        # Add warning symbol for insecure state
        warning = Text("⚠", font_size=40, color=ORANGE_3B1B, weight=BOLD)
        warning.next_to(insecure_circle, DOWN, buff=0.3)
        self.play(FadeIn(warning, scale=1.5), run_time=0.5)
        
        # Description for insecure state
        insecure_desc = Text(
            "Operating limits OK\nVulnerable to contingencies",
            font_size=12,
            color=ORANGE_3B1B
        )
        insecure_desc.next_to(warning, DOWN, buff=0.2)
        self.play(FadeIn(insecure_desc, scale=0.8), run_time=0.6)
        
        self.wait(0.5)
        
        # Animate boundary to emphasize these are within Normal State
        boundary_highlight = normal_box.copy().set_stroke(BLUE_3B1B, width=6)
        self.play(
            ShowPassingFlash(boundary_highlight, time_width=0.8),
            run_time=2
        )
        
        self.wait(1)
        
        # EMERGENCY STATE (outside Normal State - show transition)
        emergency_box = RoundedRectangle(
            width=6, height=2.5,
            corner_radius=0.25,
            color=RED_3B1B,
            fill_opacity=0.2,
            stroke_width=4
        )
        emergency_box.shift(DOWN * 3.5)
        
        emergency_label = Text("Emergency State of Operation", font_size=20, color=RED_3B1B, weight=BOLD)
        emergency_label.move_to(emergency_box.get_center() + UP * 0.6)
        
        # Show emergency state appearing
        self.play(
            FadeIn(emergency_box, shift=UP*0.5),
            Flash(emergency_box, color=RED_3B1B, flash_radius=1.5),
            run_time=1
        )
        self.play(Write(emergency_label), run_time=0.8)

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # Two types of violations
        violation1 = Text("Violation of\nLong-Term Ratings", font_size=14, color=RED_3B1B)
        violation1.move_to(emergency_box.get_center() + LEFT * 2 + DOWN * 0.4)
        
        violation2 = Text("Violation of\nShort-Term Ratings", font_size=14, color=RED_3B1B)
        violation2.move_to(emergency_box.get_center() + RIGHT * 2 + DOWN * 0.4)
        
        self.play(
            Write(violation1),
            Write(violation2),
            run_time=0.8
        )
        
        self.wait(2)