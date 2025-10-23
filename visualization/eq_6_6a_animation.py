from manim import *

class Equation6_6a(Scene):
    def construct(self):
        # 3Blue1Brown style colors
        BLUE_E_3B1B = "#1C758A"
        BLUE_D_3B1B = "#29ABCA"
        BLUE_C_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        
        # Title
        title = Text("Transmission Line Thermal Constraint\non Post-Contingency Flow", 
                    font_size=36, color=BLUE_C_3B1B)
        title.to_edge(UP)
        self.play(Write(title))
        self.play(Flash(title, color=YELLOW_3B1B, flash_radius=1.0))
        self.wait(0.5)
        
        # Build the equation in parts with 3B1B style
        # Use smaller font size to fit everything
        # Left side of inequality - First term
        term1 = MathTex(
            r"E_{\Gamma}^{(\omega)}[{\psi}_{\text{init}}^{(\tau=0)}]",
            color=BLUE_D_3B1B,
            font_size=32
        )
        
        # Second term
        plus1 = MathTex("+", color=WHITE, font_size=32)
        term2 = MathTex(
            r"(1-E_{\Gamma}^{(\omega)})[{\psi}_{\text{amb}}]",
            color=GREEN_3B1B,
            font_size=32
        )
        
        # Third term with fraction
        plus2 = MathTex("+", color=WHITE, font_size=32)
        fraction = MathTex(
            r"\Big(\frac{\alpha'}{\beta'}\Big)",
            color=YELLOW_3B1B,
            font_size=32
        )
        
        # The bracket with three components
        bracket_open = MathTex(r"\Big[", color=WHITE, font_size=32)
        
        # First component in bracket
        component1 = MathTex(
            r"(P_{T_r}^{(\tau=0)})^2E_0^{(\omega)}",
            color=BLUE_C_3B1B,
            font_size=32
        )
        
        plus3 = MathTex("+", color=WHITE, font_size=32)
        
        # Second component
        component2 = MathTex(
            r"(P_{T_r}^{(\epsilon)})^2E_{\epsilon}^{(\omega)}",
            color=BLUE_C_3B1B,
            font_size=32
        )
        
        plus4 = MathTex("+", color=WHITE, font_size=32)
        
        # Summation component
        component3 = MathTex(
            r"\sum_{\tau=1}^{\Gamma_{RND}-(\omega+1)}(P_{T_r}^{(\tau)})^2E_{\tau}^{(\omega)}",
            color=BLUE_C_3B1B,
            font_size=32
        )
        
        bracket_close = MathTex(r"\Big]", color=WHITE, font_size=32)
        
        # Inequality and threshold
        inequality = MathTex(r"<", color=WHITE, font_size=32)
        threshold = MathTex(
            r"{\psi}_{T_r}^{max}",
            color="#FF6B6B",
            font_size=32
        )
        
        # Animate first term with silhouette to solid effect
        term1.move_to(ORIGIN).shift(UP * 1.2 + LEFT * 2)
        # Create silhouette version
        term1_outline = term1.copy().set_fill(opacity=0).set_stroke(BLUE_D_3B1B, width=2)
        self.play(Create(term1_outline), run_time=0.8)
        self.play(
            FadeOut(term1_outline),
            FadeIn(term1),
            Flash(term1, color=YELLOW_3B1B, flash_radius=0.5),
            run_time=0.8
        )
        self.wait(0.3)
        
        # Add second term on same line
        plus1.next_to(term1, RIGHT, buff=0.15)
        term2.next_to(plus1, RIGHT, buff=0.15)
        
        self.play(FadeIn(plus1, shift=DOWN*0.3))
        # Silhouette to solid for term2
        term2_outline = term2.copy().set_fill(opacity=0).set_stroke(GREEN_3B1B, width=2)
        self.play(Create(term2_outline), run_time=0.8)
        self.play(
            FadeOut(term2_outline),
            FadeIn(term2),
            Flash(term2, color=YELLOW_3B1B, flash_radius=0.5),
            run_time=0.8
        )
        self.wait(0.3)
        
        # Add the fraction term on a NEW LINE
        plus2.next_to(term1, DOWN, buff=0.4).align_to(term1, LEFT)
        fraction.next_to(plus2, RIGHT, buff=0.15)
        
        self.play(FadeIn(plus2, shift=DOWN*0.3))
        # Silhouette to solid for fraction
        fraction_outline = fraction.copy().set_fill(opacity=0).set_stroke(YELLOW_3B1B, width=2)
        self.play(Create(fraction_outline), run_time=0.8)
        self.play(
            FadeOut(fraction_outline),
            FadeIn(fraction),
            Flash(fraction, color=YELLOW_3B1B, flash_radius=0.5),
            run_time=0.8
        )
        self.wait(0.3)
        
        # Start the bracket and its components on the same line as fraction
        bracket_open.next_to(fraction, RIGHT, buff=0.1)
        self.play(Write(bracket_open), run_time=0.5)
        
        # Position for first component on THIRD LINE
        component1.next_to(plus2, DOWN, buff=0.4).shift(RIGHT * 0.5)
        
        # Silhouette to solid for component1
        comp1_outline = component1.copy().set_fill(opacity=0).set_stroke(BLUE_C_3B1B, width=2)
        self.play(Create(comp1_outline), run_time=0.8)
        self.play(
            FadeOut(comp1_outline),
            FadeIn(component1),
            Flash(component1, color=YELLOW_3B1B, flash_radius=0.5),
            run_time=0.8
        )
        self.wait(0.3)
        
        # Add second component
        plus3.next_to(component1, RIGHT, buff=0.15)
        component2.next_to(plus3, RIGHT, buff=0.15)
        
        self.play(FadeIn(plus3, shift=DOWN*0.3))
        # Silhouette to solid for component2
        comp2_outline = component2.copy().set_fill(opacity=0).set_stroke(BLUE_C_3B1B, width=2)
        self.play(Create(comp2_outline), run_time=0.8)
        self.play(
            FadeOut(comp2_outline),
            FadeIn(component2),
            Flash(component2, color=YELLOW_3B1B, flash_radius=0.5),
            run_time=0.8
        )
        self.wait(0.3)
        
        # Add summation on FOURTH LINE
        plus4.next_to(component1, DOWN, buff=0.4).align_to(component1, LEFT)
        component3.next_to(plus4, RIGHT, buff=0.15)
        
        self.play(FadeIn(plus4, shift=DOWN*0.3))
        # Silhouette to solid for component3
        comp3_outline = component3.copy().set_fill(opacity=0).set_stroke(BLUE_C_3B1B, width=2)
        self.play(Create(comp3_outline), run_time=1.0)
        self.play(
            FadeOut(comp3_outline),
            FadeIn(component3),
            Flash(component3, color=YELLOW_3B1B, flash_radius=0.7),
            run_time=1.0
        )
        self.wait(0.3)
        
        # Close bracket - position it after the last term
        bracket_close.next_to(component3, RIGHT, buff=0.1)
        self.play(Write(bracket_close), run_time=0.5)
        self.wait(0.3)
        
        # Add inequality and threshold on same line as closing bracket
        inequality.next_to(bracket_close, RIGHT, buff=0.2)
        threshold.next_to(inequality, RIGHT, buff=0.2)
        
        self.play(Write(inequality), run_time=0.5)
        # Silhouette to solid for threshold
        threshold_outline = threshold.copy().set_fill(opacity=0).set_stroke("#FF6B6B", width=2)
        self.play(Create(threshold_outline), run_time=0.8)
        self.play(
            FadeOut(threshold_outline),
            FadeIn(threshold),
            threshold.animate.set_color("#FF3333"),
            Flash(threshold, color="#FF3333", flash_radius=0.5),
            run_time=1
        )
        self.wait(0.5)
        
        # Highlight the entire equation
        full_equation = VGroup(
            term1, plus1, term2, plus2, fraction, bracket_open,
            component1, plus3, component2, plus4, component3,
            bracket_close, inequality, threshold
        )
        
        self.play(Indicate(full_equation, scale_factor=1.05, color=YELLOW_3B1B), run_time=2)
        self.wait(1)
        
        # Add the constraint below
        constraint = MathTex(
            r"\forall\omega\in\{0,1,2,...(\Gamma_{RND}-1)\}",
            font_size=36,
            color=YELLOW_3B1B
        )
        constraint.next_to(full_equation, DOWN, buff=0.8)
        
        self.play(FadeIn(constraint, shift=UP*0.3), run_time=1)
        self.play(Indicate(constraint, color=YELLOW_3B1B))
        self.wait(2)