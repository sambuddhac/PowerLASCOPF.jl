from manim import *

class CompleteStateDiagram(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        YELLOW_3B1B = "#FFFF00"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("Complete Power System State Diagram", font_size=32, color=BLUE_3B1B)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # Central State: Normal Secure
        center_state = Circle(
            radius=1.2,
            color=GREEN_3B1B,
            fill_opacity=0.3,
            stroke_width=4
        )
        center_state.move_to(ORIGIN)
        
        center_label = Text("Normal\nSecure State\nof Network\nOperation", 
                           font_size=14, color=GREEN_3B1B, weight=BOLD)
        center_label.move_to(center_state)
        
        # Animate center state with emphasis
        center_outline = center_state.copy().set_fill(opacity=0).set_stroke(GREEN_3B1B, width=8)
        self.play(Create(center_outline), run_time=0.8)
        self.play(
            FadeOut(center_outline),
            FadeIn(center_state),
            Flash(center_state, color=GREEN_3B1B, flash_radius=1.5, num_lines=16),
            run_time=1
        )
        self.play(Write(center_label), run_time=0.8)
        self.wait(0.5)
        
        # State 1: Emergency State (Violating Short-Term Limits)
        emergency_short = RoundedRectangle(
            width=2.2, height=1.5,
            corner_radius=0.2,
            color=RED_3B1B,
            fill_opacity=0.35,
            stroke_width=3
        )
        emergency_short.shift(UP * 2.8)
        
        emergency_short_label = Text("Emergency\nState of Network\nOperation", 
                                    font_size=12, color=RED_3B1B, weight=BOLD)
        emergency_short_label.move_to(emergency_short)
        
        # Contingency arrow to Emergency (short-term violation)
        cont_to_emerg = CurvedArrow(
            start_point=center_state.get_top() + UP * 0.1,
            end_point=emergency_short.get_bottom() + DOWN * 0.1,
            color=RED_3B1B,
            stroke_width=4,
            tip_length=0.3,
            angle=-TAU/8
        )
        
        cont_label1 = Text("Occurrence of\na Contingency", font_size=11, color=RED_3B1B, weight=BOLD)
        cont_label1.next_to(cont_to_emerg, LEFT, buff=0.2)
        
        # Animate contingency event
        self.play(
            Flash(center_state, color=RED_3B1B, flash_radius=1.5, line_length=0.4),
            run_time=0.6
        )
        self.play(Create(cont_to_emerg), run_time=1)
        self.play(Write(cont_label1), run_time=0.6)
        
        # Animate emergency state
        self.play(
            FadeIn(emergency_short, scale=1.2),
            Flash(emergency_short, color=RED_3B1B, flash_radius=1.2),
            run_time=1
        )
        self.play(Write(emergency_short_label), run_time=0.7)
        
        # Add violation note
        violation_short = Text("Violating\nShort-Term Limits", font_size=10, color=RED_3B1B)
        violation_short.next_to(emergency_short, UP, buff=0.15)
        self.play(FadeIn(violation_short, scale=0.8), run_time=0.5)
        
        self.wait(0.5)
        
        # State 2: Emergency State (Violating Long-Term Limits)
        emergency_long = RoundedRectangle(
            width=2.2, height=1.5,
            corner_radius=0.2,
            color=ORANGE_3B1B,
            fill_opacity=0.35,
            stroke_width=3
        )
        emergency_long.shift(LEFT * 4 + DOWN * 0.5)
        
        emergency_long_label = Text("Emergency State\nViolating\nLong-Term Limits", 
                                   font_size=11, color=ORANGE_3B1B, weight=BOLD)
        emergency_long_label.move_to(emergency_long)
        
        # Transition from short-term to long-term violation
        short_to_long = Arrow(
            start=emergency_short.get_left() + DOWN * 0.3,
            end=emergency_long.get_top() + UP * 0.1,
            color=ORANGE_3B1B,
            stroke_width=3,
            tip_length=0.25
        )
        
        time_label = Text("Time\nElapsed", font_size=10, color=ORANGE_3B1B)
        time_label.next_to(short_to_long, LEFT, buff=0.15)
        
        self.play(Create(short_to_long), run_time=0.8)
        self.play(Write(time_label), run_time=0.5)
        
        self.play(
            FadeIn(emergency_long, scale=1.1),
            Flash(emergency_long, color=ORANGE_3B1B, flash_radius=1.0),
            run_time=0.9
        )
        self.play(Write(emergency_long_label), run_time=0.7)
        
        self.wait(0.5)
        
        # State 3: Normal Insecure State
        insecure_state = RoundedRectangle(
            width=2.2, height=1.5,
            corner_radius=0.2,
            color=YELLOW_3B1B,
            fill_opacity=0.25,
            stroke_width=3
        )
        insecure_state.shift(RIGHT * 4 + DOWN * 0.5)
        
        insecure_label = Text("Normal\nInsecure State\nof Network\nOperation", 
                             font_size=11, color=YELLOW_3B1B, weight=BOLD)
        insecure_label.move_to(insecure_state)
        
        # Corrective action from emergency to insecure
        emerg_to_insec = CurvedArrow(
            start_point=emergency_long.get_bottom() + DOWN * 0.1,
            end_point=insecure_state.get_left() + LEFT * 0.1,
            color=PURPLE_3B1B,
            stroke_width=3,
            tip_length=0.25,
            angle=TAU/6
        )
        
        corrective_label = Text("Corrective\nAction", font_size=10, color=PURPLE_3B1B, weight=BOLD)
        corrective_label.next_to(emerg_to_insec, DOWN, buff=0.2)
        
        self.play(Create(emerg_to_insec), run_time=1)
        self.play(Write(corrective_label), run_time=0.6)
        
        insecure_outline = insecure_state.copy().set_fill(opacity=0).set_stroke(YELLOW_3B1B, width=5)
        self.play(Create(insecure_outline), run_time=0.6)
        self.play(
            FadeOut(insecure_outline),
            FadeIn(insecure_state),
            Flash(insecure_state, color=YELLOW_3B1B, flash_radius=0.9),
            run_time=0.8
        )
        self.play(Write(insecure_label), run_time=0.7)
        
        self.wait(0.5)
        
        # Return to secure from insecure
        insec_to_secure = CurvedArrow(
            start_point=insecure_state.get_top() + UP * 0.1,
            end_point=center_state.get_right() + RIGHT * 0.1 + UP * 0.3,
            color=GREEN_3B1B,
            stroke_width=3,
            tip_length=0.25,
            angle=TAU/6
        )
        
        return_label = Text("Return to\nSecurity", font_size=10, color=GREEN_3B1B, weight=BOLD)
        return_label.next_to(insec_to_secure, UP, buff=0.1)
        
        self.play(Create(insec_to_secure), run_time=1.2)
        self.play(Write(return_label), run_time=0.6)
        
        self.wait(0.5)
        
        # Another contingency path (direct to insecure)
        cont_to_insec = CurvedArrow(
            start_point=center_state.get_right() + RIGHT * 0.1 + DOWN * 0.3,
            end_point=insecure_state.get_top() + LEFT * 0.5 + UP * 0.1,
            color=YELLOW_3B1B,
            stroke_width=3,
            tip_length=0.2,
            angle=-TAU/8
        )
        
        cont_label2 = Text("Contingency", font_size=9, color=YELLOW_3B1B, weight=BOLD)
        cont_label2.next_to(cont_to_insec, DOWN, buff=0.1)
        
        self.play(
            Flash(center_state, color=YELLOW_3B1B, flash_radius=1.2),
            run_time=0.5
        )
        self.play(Create(cont_to_insec), run_time=1)
        self.play(Write(cont_label2), run_time=0.5)
        
        self.wait(0.5)
        
        # Highlight the complete cycle with animation
        all_states = VGroup(center_state, emergency_short, emergency_long, insecure_state)
        
        for state in all_states:
            self.play(
                Flash(state, color=BLUE_3B1B, flash_radius=0.8, line_length=0.2),
                run_time=0.4
            )
        
        self.wait(0.5)
        
        # Add legend
        legend_box = Rectangle(
            width=3.5, height=2.2,
            color=WHITE,
            fill_opacity=0.05,
            stroke_width=1.5
        )
        legend_box.to_corner(DR, buff=0.4)
        
        legend_title = Text("State Classification", font_size=12, color=WHITE, weight=BOLD)
        legend_title.next_to(legend_box.get_top(), DOWN, buff=0.15)
        
        legend_items = VGroup(
            VGroup(
                Circle(radius=0.15, color=GREEN_3B1B, fill_opacity=0.5),
                Text("Secure", font_size=10, color=WHITE)
            ).arrange(RIGHT, buff=0.15),
            VGroup(
                Circle(radius=0.15, color=YELLOW_3B1B, fill_opacity=0.5),
                Text("Insecure", font_size=10, color=WHITE)
            ).arrange(RIGHT, buff=0.15),
            VGroup(
                Circle(radius=0.15, color=ORANGE_3B1B, fill_opacity=0.5),
                Text("Emergency (Long)", font_size=9, color=WHITE)
            ).arrange(RIGHT, buff=0.15),
            VGroup(
                Circle(radius=0.15, color=RED_3B1B, fill_opacity=0.5),
                Text("Emergency (Short)", font_size=9, color=WHITE)
            ).arrange(RIGHT, buff=0.15)
        )
        legend_items.arrange(DOWN, aligned_edge=LEFT, buff=0.18)
        legend_items.next_to(legend_title, DOWN, buff=0.2)
        
        self.play(
            Create(legend_box),
            Write(legend_title),
            run_time=0.7
        )
        self.play(
            *[FadeIn(item, shift=RIGHT*0.2) for item in legend_items],
            run_time=1
        )
        
        self.wait(2)
        
        # Add restoration time annotation
        restoration_note = Text(
            "ΓRND: Restoration intervals to return to normal",
            font_size=10,
            color=BLUE_3B1B
        )
        restoration_note.to_edge(DOWN, buff=0.3)
        
        restoration_box = SurroundingRectangle(
            restoration_note,
            color=BLUE_3B1B,
            buff=0.12,
            corner_radius=0.08
        )
        
        self.play(
            Create(restoration_box),
            Write(restoration_note),
            run_time=0.8
        )
        
        self.wait(2)