from manim import *
import numpy as np
from scipy.special import erf

class CVaRVisualization(Scene):
    def construct(self):
        # Title
        title = Text("Conditional Value at Risk (CVaR)", font_size=48)
        title.to_edge(UP)
        subtitle = Text("Risk-Minimizing Stochastic Optimization for Power Systems", 
                       font_size=24, color=GREY)
        subtitle.next_to(title, DOWN)
        
        self.play(Write(title), Write(subtitle))
        self.wait(2)
        self.play(FadeOut(title), FadeOut(subtitle))
        
        # Scene 1: Weather Scenarios
        self.show_weather_scenarios()
        self.wait(1)
        
        # Scene 2: Cost Distribution
        self.show_cost_distribution()
        self.wait(1)
        
        # Scene 3: CVaR Explanation
        self.show_cvar_concept()
        self.wait(1)
        
        # Scene 4: Objective Function
        self.show_objective_function()
        self.wait(2)

    def show_weather_scenarios(self):
        """Show how weather scenarios affect VRE generation and load"""
        scene_title = Text("Weather Scenarios → Generation & Load", font_size=36)
        scene_title.to_edge(UP)
        self.play(Write(scene_title))
        
        # Create weather icons
        sun = Circle(radius=0.3, color=YELLOW, fill_opacity=1)
        sun_rays = VGroup(*[Line(ORIGIN, 0.5*UP).rotate(i*PI/4) 
                           for i in range(8)]).set_color(YELLOW)
        sunny = VGroup(sun, sun_rays).scale(0.8)
        
        cloud = Ellipse(width=0.8, height=0.4, color=GREY, fill_opacity=0.8)
        cloudy = cloud.copy()
        
        # Weather scenario labels
        scenarios = VGroup(
            VGroup(sunny.copy(), Text("Sunny", font_size=20).next_to(sunny, DOWN)),
            VGroup(cloudy, Text("Cloudy", font_size=20).next_to(cloudy, DOWN)),
        ).arrange(RIGHT, buff=2)
        scenarios.shift(UP)
        
        self.play(FadeIn(scenarios))
        self.wait(1)
        
        # Show arrows to different outcomes
        arrow1 = Arrow(scenarios[0].get_bottom(), DOWN*1.5, color=GREEN)
        arrow2 = Arrow(scenarios[1].get_bottom(), DOWN*1.5, color=ORANGE)
        
        outcome1 = VGroup(
            Text("High Solar", font_size=18, color=GREEN),
            Text("Normal Load", font_size=18, color=GREEN)
        ).arrange(DOWN, buff=0.1).next_to(arrow1, DOWN)
        
        outcome2 = VGroup(
            Text("Low Solar", font_size=18, color=ORANGE),
            Text("High Load", font_size=18, color=ORANGE)
        ).arrange(DOWN, buff=0.1).next_to(arrow2, DOWN)
        
        self.play(
            GrowArrow(arrow1), GrowArrow(arrow2),
            FadeIn(outcome1), FadeIn(outcome2)
        )
        self.wait(2)
        
        # Clear for next scene
        self.play(*[FadeOut(mob) for mob in self.mobjects])

    def show_cost_distribution(self):
        """Show the probability distribution of costs"""
        scene_title = Text("Cost Distribution Across Scenarios", font_size=36)
        scene_title.to_edge(UP)
        self.play(Write(scene_title))
        
        # Create axes
        axes = Axes(
            x_range=[0, 10, 1],
            y_range=[0, 0.4, 0.1],
            x_length=10,
            y_length=5,
            axis_config={"color": BLUE},
            tips=False
        ).shift(DOWN*0.5)
        
        x_label = axes.get_x_axis_label(r"\text{Cost } (\mathcal{C})", 
                                        direction=DOWN, buff=0.3)
        y_label = axes.get_y_axis_label(r"\text{Probability Density}", 
                                        direction=LEFT, buff=0.3)
        
        self.play(Create(axes), Write(x_label), Write(y_label))
        
        # Create probability distribution (slightly skewed normal)
        def cost_pdf(x):
            # Skewed normal distribution
            mu, sigma, alpha = 5, 1.5, 2
            normal = (1/(sigma*np.sqrt(2*np.pi))) * np.exp(-0.5*((x-mu)/sigma)**2)
            skew = 1 + erf(alpha*(x-mu)/(sigma*np.sqrt(2)))
            return normal * skew * 0.6
        
        # Plot the distribution
        graph = axes.plot(cost_pdf, x_range=[1, 9], color=BLUE_C)
        graph_area = axes.get_area(graph, x_range=[1, 9], color=BLUE_C, opacity=0.3)
        
        self.play(Create(graph), FadeIn(graph_area))
        self.wait(1)
        
        # Add scenario markers
        scenario_costs = [3.5, 4.2, 4.8, 5.5, 6.2, 7.5, 8.2]
        scenario_probs = [cost_pdf(c) for c in scenario_costs]
        
        scenario_dots = VGroup(*[
            Dot(axes.c2p(sc, cost_pdf(sc)), color=YELLOW, radius=0.08)
            for sc in scenario_costs
        ])
        
        scenario_label = Text("Weather Scenarios", font_size=20, color=YELLOW)
        scenario_label.next_to(scenario_dots, UP, buff=0.5)
        
        self.play(FadeIn(scenario_dots), Write(scenario_label))
        self.wait(2)
        
        # Store for next scene
        self.axes = axes
        self.graph = graph
        self.graph_area = graph_area
        self.cost_pdf = cost_pdf
        self.scenario_dots = scenario_dots
        
        # Clear labels
        self.play(FadeOut(scene_title), FadeOut(scenario_label))

    def show_cvar_concept(self):
        """Illustrate VaR and CVaR"""
        scene_title = Text("Value at Risk (VaR) & CVaR", font_size=36)
        scene_title.to_edge(UP)
        self.play(Write(scene_title))
        
        axes = self.axes
        graph = self.graph
        
        # VaR threshold (e.g., 95th percentile)
        alpha = 0.10  # tail risk parameter (1 - confidence level)
        
        # Find VaR (approximate for our distribution)
        var_value = 7.0  # This would be calculated properly
        
        # Draw VaR line
        var_line = DashedLine(
            axes.c2p(var_value, 0),
            axes.c2p(var_value, self.cost_pdf(var_value)),
            color=RED
        )
        var_label = MathTex(r"\Psi \text{ (VaR)}", color=RED, font_size=28)
        var_label.next_to(var_line, DOWN)
        
        self.play(Create(var_line), Write(var_label))
        self.wait(1)
        
        # Highlight tail region
        tail_area = axes.get_area(
            graph, 
            x_range=[var_value, 9], 
            color=RED, 
            opacity=0.5
        )
        
        tail_label = Text(r"Tail Risk Region", font_size=24, color=RED)
        tail_label.next_to(axes.c2p(8, 0.15), RIGHT)
        tail_arrow = Arrow(
            tail_label.get_left(),
            axes.c2p(7.5, 0.08),
            color=RED,
            buff=0.1
        )
        
        self.play(FadeIn(tail_area))
        self.play(Write(tail_label), GrowArrow(tail_arrow))
        self.wait(2)
        
        # Show CVaR (expected value in tail)
        cvar_value = 7.8
        cvar_line = Line(
            axes.c2p(var_value, 0),
            axes.c2p(var_value, 0.35),
            color=ORANGE,
            stroke_width=6
        )
        cvar_indicator = Line(
            axes.c2p(cvar_value, 0),
            axes.c2p(cvar_value, 0.25),
            color=ORANGE,
            stroke_width=8
        )
        
        cvar_label = MathTex(
            r"\text{CVaR} = \Psi + \frac{1}{\alpha}\mathbb{E}[V]",
            color=ORANGE,
            font_size=28
        )
        cvar_label.next_to(axes.c2p(8, 0.25), UP)
        
        cvar_explanation = Text(
            "Expected cost in tail region",
            font_size=20,
            color=ORANGE
        ).next_to(cvar_label, DOWN, buff=0.2)
        
        self.play(
            Create(cvar_indicator),
            Write(cvar_label),
            Write(cvar_explanation)
        )
        self.wait(2)
        
        # Store for next scene
        self.var_line = var_line
        self.var_label = var_label
        self.tail_area = tail_area
        self.cvar_label = cvar_label
        self.cvar_indicator = cvar_indicator
        
        self.play(FadeOut(scene_title), FadeOut(tail_label), FadeOut(tail_arrow), 
                  FadeOut(cvar_explanation))

    def show_objective_function(self):
        """Show how CVaR is incorporated in the objective function"""
        scene_title = Text("LASCOPF Objective Function", font_size=36)
        scene_title.to_edge(UP)
        self.play(Write(scene_title))
        
        # Objective function formulation
        obj_func = MathTex(
            r"\min_{P_g} \Big[(1-\beta_{CVaR})", 
            r"\mathbb{E}[\mathcal{C}]",
            r"+ \beta_{CVaR}",
            r"\text{CVaR}",
            r"\Big]",
            font_size=32
        ).shift(UP*2)
        
        self.play(Write(obj_func))
        self.wait(1)
        
        # Highlight expected cost
        expected_box = SurroundingRectangle(obj_func[1], color=BLUE, buff=0.1)
        expected_label = Text("Expected Cost", font_size=20, color=BLUE)
        expected_label.next_to(expected_box, DOWN, buff=0.3)
        
        self.play(Create(expected_box), Write(expected_label))
        self.wait(1)
        
        # Highlight CVaR term
        cvar_box = SurroundingRectangle(obj_func[3], color=ORANGE, buff=0.1)
        cvar_term_label = Text("Tail Risk Measure", font_size=20, color=ORANGE)
        cvar_term_label.next_to(cvar_box, DOWN, buff=0.8)
        
        self.play(
            Transform(expected_box, cvar_box),
            Transform(expected_label, cvar_term_label)
        )
        self.wait(1)
        
        self.play(FadeOut(expected_box), FadeOut(expected_label))
        
        # Show trade-off parameter
        beta_box = SurroundingRectangle(
            VGroup(obj_func[0], obj_func[2]), 
            color=GREEN, 
            buff=0.1
        )
        beta_label = Text(
            r"Trade-off parameter",
            font_size=20,
            color=GREEN
        ).next_to(beta_box, DOWN, buff=0.3)
        
        beta_explanation = VGroup(
            Text(r"Large β → More risk-averse", font_size=18, color=GREEN),
            Text(r"Small β → Focus on expected cost", font_size=18, color=GREEN)
        ).arrange(DOWN, buff=0.1).next_to(beta_label, DOWN, buff=0.2)
        
        self.play(
            Create(beta_box),
            Write(beta_label),
            Write(beta_explanation)
        )
        self.wait(2)
        
        # Show expanded CVaR
        cvar_expanded = MathTex(
            r"\text{CVaR} = \Psi + \frac{1}{\alpha_{CVaR}}\mathbb{E}[V]",
            font_size=28
        ).next_to(obj_func, DOWN, buff=1)
        
        constraint = MathTex(
            r"V^{sc} \geq \Psi - \mathcal{C}^{sc}, \quad V^{sc} \geq 0",
            font_size=24
        ).next_to(cvar_expanded, DOWN, buff=0.3)
        
        self.play(Write(cvar_expanded))
        self.play(Write(constraint))
        self.wait(2)
        
        # Final summary
        summary_title = Text("Key Benefits:", font_size=28, color=YELLOW)
        summary_title.shift(DOWN*1.5)
        
        benefits = VGroup(
            Text("• Minimizes expected cost", font_size=20),
            Text("• Limits exposure to extreme scenarios", font_size=20),
            Text("• Ensures (N-1-1) security with restoration", font_size=20),
        ).arrange(DOWN, buff=0.15, aligned_edge=LEFT)
        benefits.next_to(summary_title, DOWN, buff=0.3)
        
        self.play(Write(summary_title))
        self.play(FadeIn(benefits, shift=UP))
        self.wait(3)


class SimplifiedCVaRDemo(Scene):
    """Simplified version focusing on the distribution visualization"""
    def construct(self):
        # Title
        title = Text("CVaR: Protecting Against Tail Risk", font_size=42)
        title.to_edge(UP)
        self.play(Write(title))
        self.wait(1)
        
        # Create axes
        axes = Axes(
            x_range=[0, 10, 1],
            y_range=[0, 0.4, 0.1],
            x_length=11,
            y_length=5,
            axis_config={"color": GREY},
            tips=False
        ).shift(DOWN*0.8)
        
        x_label = axes.get_x_axis_label(
            r"\text{Generation Cost } (\$)", 
            direction=DOWN
        )
        y_label = axes.get_y_axis_label(
            r"\text{Probability}", 
            direction=LEFT
        )
        
        self.play(Create(axes), Write(x_label), Write(y_label))
        
        # Create distribution
        def pdf(x):
            mu, sigma = 5, 1.3
            return (1/(sigma*np.sqrt(2*np.pi))) * np.exp(-0.5*((x-mu)/sigma)**2)
        
        graph = axes.plot(pdf, x_range=[1.5, 8.5], color=BLUE_C, stroke_width=4)
        area = axes.get_area(graph, x_range=[1.5, 8.5], color=BLUE_C, opacity=0.2)
        
        self.play(Create(graph), FadeIn(area))
        self.wait(1)
        
        # Expected value
        ev = 5
        ev_line = DashedLine(
            axes.c2p(ev, 0),
            axes.c2p(ev, pdf(ev)),
            color=GREEN,
            stroke_width=3
        )
        ev_label = MathTex(r"\mathbb{E}[\mathcal{C}]", color=GREEN)
        ev_label.next_to(ev_line, DOWN)
        
        self.play(Create(ev_line), Write(ev_label))
        self.wait(1)
        
        # VaR line
        var_val = 7.2
        var_line = DashedLine(
            axes.c2p(var_val, 0),
            axes.c2p(var_val, pdf(var_val)),
            color=YELLOW,
            stroke_width=3
        )
        var_label = MathTex(r"\Psi", color=YELLOW)
        var_label.next_to(var_line, DOWN)
        
        # Tail
        tail = axes.get_area(
            graph,
            x_range=[var_val, 8.5],
            color=RED,
            opacity=0.6
        )
        
        tail_label = Text("α = 10%", font_size=24, color=RED)
        tail_label.next_to(axes.c2p(7.8, 0.1), UP)
        
        self.play(Create(var_line), Write(var_label))
        self.play(FadeIn(tail), Write(tail_label))
        self.wait(1)
        
        # CVaR
        cvar_val = 7.7
        cvar_line = Line(
            axes.c2p(cvar_val, 0),
            axes.c2p(cvar_val, pdf(cvar_val)+0.05),
            color=ORANGE,
            stroke_width=6
        )
        cvar_label = Text("CVaR", color=ORANGE, font_size=28)
        cvar_label.next_to(cvar_line, UP, buff=0.2)
        
        self.play(Create(cvar_line), Write(cvar_label))
        self.wait(2)
        
        # Show objective
        objective = MathTex(
            r"\min \Big[(1-\beta)\mathbb{E}[\mathcal{C}] + \beta \cdot \text{CVaR}\Big]",
            font_size=36
        )
        objective.to_edge(DOWN, buff=0.5)
        
        box = SurroundingRectangle(objective, color=WHITE, buff=0.2)
        
        self.play(Write(objective), Create(box))
        self.wait(3)


# To render, use one of these commands:
# manim -pql cvar_animation.py CVaRVisualization
# manim -pql cvar_animation.py SimplifiedCVaRDemo
