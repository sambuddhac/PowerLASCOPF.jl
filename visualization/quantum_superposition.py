from manim import *

class QuantumSuperposition(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("Quantum Superposition & Measurement", font_size=36, color=BLUE_3B1B)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # Qubit state equation
        qubit_eq = MathTex(
            r"|\psi\rangle = \alpha|0\rangle + \beta|1\rangle",
            font_size=40,
            color=BLUE_3B1B
        )
        qubit_eq.shift(UP * 2)
        
        self.play(Write(qubit_eq), run_time=1.2)
        self.wait(0.5)
        
        # Normalization condition
        norm_eq = MathTex(
            r"|\alpha|^2 + |\beta|^2 = 1",
            font_size=32,
            color=GREEN_3B1B
        )
        norm_eq.next_to(qubit_eq, DOWN, buff=0.4)
        
        self.play(FadeIn(norm_eq, scale=0.8), run_time=0.8)
        self.wait(0.5)
        
        # Show specific example: equal superposition
        example_eq = MathTex(
            r"|\psi\rangle = \frac{1}{\sqrt{2}}|0\rangle + \frac{1}{\sqrt{2}}|1\rangle = |+\rangle",
            font_size=36,
            color=YELLOW_3B1B
        )
        example_eq.shift(UP * 0.3)
        
        self.play(
            qubit_eq.animate.shift(UP * 0.5),
            norm_eq.animate.shift(UP * 0.5),
            run_time=0.6
        )
        self.play(Write(example_eq), run_time=1.2)
        self.wait(0.8)
        
        # Visual representation of superposition
        # Before measurement box
        before_box = RoundedRectangle(
            width=3, height=3,
            corner_radius=0.2,
            color=PURPLE_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        before_box.shift(LEFT * 3.5 + DOWN * 1.5)
        
        before_label = Text("Before\nMeasurement", font_size=18, color=PURPLE_3B1B, weight=BOLD)
        before_label.next_to(before_box, UP, buff=0.2)
        
        self.play(
            Create(before_box),
            Write(before_label),
            run_time=0.8
        )
        
        # Superposition visualization (both states together)
        ket_0_super = MathTex(r"|0\rangle", font_size=48, color=YELLOW_3B1B)
        ket_0_super.move_to(before_box.get_center() + UP * 0.3)
        
        ket_1_super = MathTex(r"|1\rangle", font_size=48, color=RED_3B1B)
        ket_1_super.move_to(before_box.get_center() + DOWN * 0.3)
        
        plus_sign = MathTex(r"+", font_size=36, color=WHITE)
        plus_sign.move_to(before_box.get_center())
        
        # Fade in with overlapping effect
        self.play(
            FadeIn(ket_0_super, scale=1.2),
            FadeIn(ket_1_super, scale=1.2),
            FadeIn(plus_sign, scale=1.2),
            run_time=1
        )
        
        # Probability waves (sine waves to show superposition)
        wave_0 = FunctionGraph(
            lambda x: 0.3 * np.sin(3 * x),
            x_range=[-1.2, 1.2],
            color=YELLOW_3B1B,
            stroke_width=3
        )
        wave_0.move_to(before_box.get_center() + UP * 0.8)
        
        wave_1 = FunctionGraph(
            lambda x: 0.3 * np.sin(3 * x + PI),
            x_range=[-1.2, 1.2],
            color=RED_3B1B,
            stroke_width=3
        )
        wave_1.move_to(before_box.get_center() + DOWN * 0.8)
        
        self.play(
            Create(wave_0),
            Create(wave_1),
            run_time=1
        )
        self.wait(0.5)
        
        # Measurement operator (eye icon)
        measurement_icon = Text("👁", font_size=60, color=ORANGE_3B1B)
        measurement_icon.move_to(ORIGIN + DOWN * 1.5)
        
        measurement_label = Text("Measurement", font_size=20, color=ORANGE_3B1B, weight=BOLD)
        measurement_label.next_to(measurement_icon, DOWN, buff=0.3)
        
        # Arrow from before to measurement
        arrow_to_measure = Arrow(
            start=before_box.get_right(),
            end=measurement_icon.get_left() + LEFT * 0.5,
            color=ORANGE_3B1B,
            stroke_width=4,
            tip_length=0.3
        )
        
        self.play(
            GrowArrow(arrow_to_measure),
            run_time=0.8
        )
        self.play(
            FadeIn(measurement_icon, scale=2),
            Write(measurement_label),
            Flash(measurement_icon, color=ORANGE_3B1B, flash_radius=1.5),
            run_time=1
        )
        self.wait(0.5)
        
        # After measurement - collapse to one state
        # Two outcome boxes
        outcome_0_box = RoundedRectangle(
            width=2, height=2,
            corner_radius=0.2,
            color=YELLOW_3B1B,
            fill_opacity=0.2,
            stroke_width=3
        )
        outcome_0_box.shift(RIGHT * 4 + UP * 0.3)
        
        outcome_1_box = RoundedRectangle(
            width=2, height=2,
            corner_radius=0.2,
            color=RED_3B1B,
            fill_opacity=0.2,
            stroke_width=3
        )
        outcome_1_box.shift(RIGHT * 4 + DOWN * 2.5)
        
        after_label = Text("After\nMeasurement", font_size=16, color=GREEN_3B1B, weight=BOLD)
        after_label.move_to(RIGHT * 4 + UP * 1.8)
        
        # Arrows to outcomes
        arrow_to_0 = Arrow(
            start=measurement_icon.get_right() + RIGHT * 0.3,
            end=outcome_0_box.get_left(),
            color=YELLOW_3B1B,
            stroke_width=3,
            tip_length=0.25
        )
        
        arrow_to_1 = Arrow(
            start=measurement_icon.get_right() + RIGHT * 0.3,
            end=outcome_1_box.get_left(),
            color=RED_3B1B,
            stroke_width=3,
            tip_length=0.25
        )
        
        # Probability labels
        prob_0 = MathTex(r"|\alpha|^2", font_size=20, color=YELLOW_3B1B)
        prob_0.next_to(arrow_to_0, UP, buff=0.1)
        
        prob_1 = MathTex(r"|\beta|^2", font_size=20, color=RED_3B1B)
        prob_1.next_to(arrow_to_1, DOWN, buff=0.1)
        
        self.play(
            Write(after_label),
            run_time=0.6
        )
        self.play(
            GrowArrow(arrow_to_0),
            GrowArrow(arrow_to_1),
            run_time=0.8
        )
        self.play(
            Write(prob_0),
            Write(prob_1),
            run_time=0.6
        )
        
        # Outcome states
        outcome_0_state = MathTex(r"|0\rangle", font_size=60, color=YELLOW_3B1B)
        outcome_0_state.move_to(outcome_0_box)
        
        outcome_1_state = MathTex(r"|1\rangle", font_size=60, color=RED_3B1B)
        outcome_1_state.move_to(outcome_1_box)
        
        self.play(
            Create(outcome_0_box),
            FadeIn(outcome_0_state, scale=1.5),
            Flash(outcome_0_box, color=YELLOW_3B1B),
            run_time=0.8
        )
        self.play(
            Create(outcome_1_box),
            FadeIn(outcome_1_state, scale=1.5),
            Flash(outcome_1_box, color=RED_3B1B),
            run_time=0.8
        )
        
        # Probability percentages (for |+⟩ state example)
        percent_0 = Text("50%", font_size=20, color=YELLOW_3B1B, weight=BOLD)
        percent_0.next_to(outcome_0_box, RIGHT, buff=0.2)
        
        percent_1 = Text("50%", font_size=20, color=RED_3B1B, weight=BOLD)
        percent_1.next_to(outcome_1_box, RIGHT, buff=0.2)
        
        self.play(
            FadeIn(percent_0, scale=0.8),
            FadeIn(percent_1, scale=0.8),
            run_time=0.6
        )
        
        self.wait(0.5)
        
        # Wave function collapse text
        collapse_text = Text(
            "Wave Function Collapse",
            font_size=18,
            color=ORANGE_3B1B,
            weight=BOLD
        )
        collapse_text.next_to(measurement_label, DOWN, buff=0.3)
        
        collapse_box = SurroundingRectangle(
            collapse_text,
            color=ORANGE_3B1B,
            buff=0.1,
            corner_radius=0.1
        )
        
        self.play(
            Create(collapse_box),
            Write(collapse_text),
            run_time=0.8
        )
        
        self.wait(1)
        
        # Highlight key insight
        insight_box = Rectangle(
            width=11, height=1.2,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=2
        )
        insight_box.to_edge(DOWN, buff=0.3)
        
        insight_text = Text(
            "Before measurement: Qubit exists in superposition\nAfter measurement: Qubit collapses to definite state",
            font_size=16,
            color=BLUE_3B1B
        )
        insight_text.move_to(insight_box)
        
        self.play(
            Create(insight_box),
            Write(insight_text),
            run_time=1.2
        )
        
        self.wait(2)