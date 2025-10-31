from manim import *

class StateTransitions(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        YELLOW_3B1B = "#FFFF00"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("Power System State Transitions", font_size=36, color=BLUE_3B1B)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # STATE 1: Normal Secure State
        secure_state = RoundedRectangle(
            width=2.5, height=1.5,
            corner_radius=0.2,
            color=GREEN_3B1B,
            fill_opacity=0.3,
            stroke_width=3
        )
        secure_state.shift(LEFT * 4 + UP * 1.5)
        
        secure_label = Text("Normal\nSecure State\nof Operation", font_size=14, color=GREEN_3B1B, weight=BOLD)
        secure_label.move_to(secure_state)
        
        # Animate secure state appearing
        secure_outline = secure_state.copy().set_fill(opacity=0).set_stroke(GREEN_3B1B, width=6)
        self.play(Create(secure_outline), run_time=0.6)
        self.play(
            FadeOut(secure_outline),
            FadeIn(secure_state),
            Flash(secure_state, color=GREEN_3B1B, flash_radius=0.8),
            run_time=0.8
        )
        self.play(Write(secure_label), run_time=0.6)
        self.wait(0.5)
        
        # TRANSITION 1: Contingency to Emergency State
        contingency_arrow1 = CurvedArrow(
            start_point=secure_state.get_bottom() + DOWN * 0.1,
            end_point=DOWN * 2 + LEFT * 4,
            color=RED_3B1B,
            stroke_width=4,
            tip_length=0.3,
            angle=-TAU/6
        )
        
        contingency_label1 = Text("Contingency", font_size=14, color=RED_3B1B, weight=BOLD)
        contingency_label1.next_to(contingency_arrow1, LEFT, buff=0.2)
        
        # Flash to indicate contingency event
        self.play(
            Flash(secure_state, color=RED_3B1B, flash_radius=1.2, line_length=0.3),
            run_time=0.5
        )
        self.play(Create(contingency_arrow1), run_time=1)
        self.play(Write(contingency_label1), run_time=0.6)
        self.wait(0.3)
        
        # STATE 2: Emergency State
        emergency_state = RoundedRectangle(
            width=2.8, height=1.5,
            corner_radius=0.2,
            color=RED_3B1B,
            fill_opacity=0.3,
            stroke_width=3
        )
        emergency_state.shift(LEFT * 4 + DOWN * 2.5)
        
        emergency_label = Text("Emergency State\nViolating\nLong-Term Limits", font_size=13, color=RED_3B1B, weight=BOLD)
        emergency_label.move_to(emergency_state)
        
        # Animate emergency state with alarm effect
        self.play(
            FadeIn(emergency_state, scale=1.2),
            Flash(emergency_state, color=RED_3B1B, flash_radius=1.0),
            run_time=1
        )
        self.play(Write(emergency_label), run_time=0.8)
        self.wait(0.5)
        
        # TRANSITION 2: Corrective Action to Insecure State
        corrective_arrow = CurvedArrow(
            start_point=emergency_state.get_right() + RIGHT * 0.1,
            end_point=RIGHT * 1 + DOWN * 2.5,
            color=PURPLE_3B1B,
            stroke_width=4,
            tip_length=0.3,
            angle=TAU/8
        )
        
        corrective_label = Text("Corrective\nAction", font_size=14, color=PURPLE_3B1B, weight=BOLD)
        corrective_label.next_to(corrective_arrow, DOWN, buff=0.2)
        
        self.play(Create(corrective_arrow), run_time=1)
        self.play(Write(corrective_label), run_time=0.6)
        self.wait(0.3)
        
        # STATE 3: Normal Insecure (then Ultimately Secure) State
        insecure_state = RoundedRectangle(
            width=3, height=1.8,
            corner_radius=0.2,
            color=ORANGE_3B1B,
            fill_opacity=0.3,
            stroke_width=3
        )
        insecure_state.shift(RIGHT * 2 + DOWN * 2.5)
        
        insecure_label = Text("Normal Insecure\n(& then Ultimately\nSecure) State of\nOperation", 
                             font_size=12, color=ORANGE_3B1B, weight=BOLD)
        insecure_label.move_to(insecure_state)
        
        # Animate insecure state
        insecure_outline = insecure_state.copy().set_fill(opacity=0).set_stroke(ORANGE_3B1B, width=6)
        self.play(Create(insecure_outline), run_time=0.6)
        self.play(
            FadeOut(insecure_outline),
            FadeIn(insecure_state),
            Flash(insecure_state, color=ORANGE_3B1B, flash_radius=0.8),
            run_time=0.8
        )
        self.play(Write(insecure_label), run_time=0.8)
        self.wait(0.5)
        
        # TRANSITION 3: Return to Security
        return_arrow = CurvedArrow(
            start_point=insecure_state.get_top() + UP * 0.1,
            end_point=secure_state.get_right() + DOWN * 0.3,
            color=GREEN_3B1B,
            stroke_width=4,
            tip_length=0.3,
            angle=TAU/4
        )
        
        return_label = Text("Return to\nSecurity", font_size=14, color=GREEN_3B1B, weight=BOLD)
        return_label.next_to(return_arrow, RIGHT, buff=0.2)
        
        self.play(Create(return_arrow), run_time=1.2)
        self.play(Write(return_label), run_time=0.6)
        self.wait(0.5)
        
        # TRANSITION 4: Another Contingency from Secure State
        contingency_arrow2 = CurvedArrow(
            start_point=secure_state.get_right() + RIGHT * 0.1,
            end_point=insecure_state.get_top() + LEFT * 0.5 + UP * 0.1,
            color=YELLOW_3B1B,
            stroke_width=3,
            tip_length=0.25,
            angle=-TAU/6
        )
        
        contingency_label2 = Text("Contingency", font_size=12, color=YELLOW_3B1B, weight=BOLD)
        contingency_label2.next_to(contingency_arrow2, UP, buff=0.1)
        
        self.play(
            Flash(secure_state, color=YELLOW_3B1B, flash_radius=1.0),
            run_time=0.5
        )
        self.play(Create(contingency_arrow2), run_time=1)
        self.play(Write(contingency_label2), run_time=0.5)
        
        self.wait(0.5)
        
        # Highlight the complete cycle
        cycle_group = VGroup(secure_state, emergency_state, insecure_state)
        self.play(
            cycle_group.animate.set_stroke(width=5),
            run_time=0.8
        )
        self.play(
            cycle_group.animate.set_stroke(width=3),
            run_time=0.8
        )
        
        self.wait(0.5)

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # Add annotation about restoration time
        time_annotation = Text(
            "Restoration: ΓRND intervals to restore security",
            font_size=11,
            color=BLUE_3B1B
        )
        time_annotation.to_edge(DOWN, buff=0.5)
        
        time_box = SurroundingRectangle(
            time_annotation,
            color=BLUE_3B1B,
            buff=0.15,
            corner_radius=0.1
        )
        
        self.play(
            Create(time_box),
            Write(time_annotation),
            run_time=0.8
        )
        
        self.wait(2)