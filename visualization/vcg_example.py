from manim import *

class VCGExample(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("VCG Example: Public Project Decision", 
                    font_size=32, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1.2)
        self.wait(0.5)
        
        # Scenario
        scenario = Text("Should a public project be built? Cost = $300", 
                       font_size=18, color=YELLOW_3B1B)
        scenario.shift(UP * 2.2)
        self.play(Write(scenario), run_time=0.9)
        self.wait(0.3)
        
        # Outcomes
        outcomes_title = Text("Possible Outcomes:", font_size=16, color=WHITE)
        outcomes_title.shift(UP * 1.5 + LEFT * 4)
        self.play(Write(outcomes_title), run_time=0.6)
        
        outcome_build = Text("ω₁ = BUILD", font_size=14, color=GREEN_3B1B, weight=BOLD)
        outcome_build.next_to(outcomes_title, DOWN, buff=0.2, aligned_edge=LEFT)
        
        outcome_no = Text("ω₂ = DON'T BUILD", font_size=14, color=RED_3B1B, weight=BOLD)
        outcome_no.next_to(outcome_build, DOWN, buff=0.15, aligned_edge=LEFT)
        
        self.play(Write(outcome_build), run_time=0.5)
        self.play(Write(outcome_no), run_time=0.5)
        
        self.wait(0.5)
        
        # Three agents with valuations
        agent_y = UP * 0.3
        agent_spacing = 3.5
        
        agents_data = [
            ("Agent 1", LEFT * agent_spacing, BLUE_3B1B, "$200", "$0"),
            ("Agent 2", ORIGIN, GREEN_3B1B, "$150", "$0"),
            ("Agent 3", RIGHT * agent_spacing, ORANGE_3B1B, "$100", "$0")
        ]
        
        agents = []
        
        for name, pos, color, val_build, val_no in agents_data:
            # Agent box
            agent_box = RoundedRectangle(
                width=2.5, height=1.5,
                corner_radius=0.12,
                color=color,
                fill_opacity=0.15,
                stroke_width=2
            )
            agent_box.shift(agent_y + pos)
            
            agent_name = Text(name, font_size=14, color=color, weight=BOLD)
            agent_name.move_to(agent_box.get_center() + UP * 0.5)
            
            val_text = VGroup(
                Text(f"v(BUILD) = {val_build}", font_size=11, color=color),
                Text(f"v(NO) = {val_no}", font_size=11, color=color)
            ).arrange(DOWN, buff=0.1)
            val_text.move_to(agent_box.get_center() + DOWN * 0.2)
            
            self.play(
                Create(agent_box),
                Write(agent_name),
                Write(val_text),
                run_time=0.7
            )
            
            agents.append((agent_box, agent_name, val_text, color, name))
        
        self.wait(0.7)
        
        # Step 1: Calculate social welfare
        step1_box = RoundedRectangle(
            width=11, height=1.3,
            corner_radius=0.15,
            color=PURPLE_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        step1_box.shift(DOWN * 1.5)
        
        step1_title = Text("Step 1: Which outcome maximizes social welfare?", 
                          font_size=16, color=PURPLE_3B1B, weight=BOLD)
        step1_title.next_to(step1_box, UP, buff=0.2)
        
        sw_calc = VGroup(
            Text("SW(BUILD) = $200 + $150 + $100 - $300 = ", font_size=14, color=GREEN_3B1B),
            Text("$150", font_size=18, color=GREEN_3B1B, weight=BOLD)
        ).arrange(RIGHT, buff=0.2)
        sw_calc.move_to(step1_box.get_center() + UP * 0.2)
        
        sw_no = VGroup(
            Text("SW(NO) = $0 + $0 + $0 = ", font_size=14, color=RED_3B1B),
            Text("$0", font_size=18, color=RED_3B1B, weight=BOLD)
        ).arrange(RIGHT, buff=0.2)
        sw_no.move_to(step1_box.get_center() + DOWN * 0.35)
        
        self.play(
            Create(step1_box),
            Write(step1_title),
            run_time=0.8
        )
        self.play(Write(sw_calc), run_time=1)
        self.play(Write(sw_no), run_time=0.8)
        
        self.wait(0.5)
        
        # Decision
        decision = Text("Decision: BUILD! (SW = $150 > $0)", 
                       font_size=16, color=GREEN_3B1B, weight=BOLD)
        decision.next_to(step1_box, DOWN, buff=0.3)
        self.play(
            Write(decision),
            Flash(decision, color=GREEN_3B1B, flash_radius=0.8),
            run_time=1
        )
        
        self.wait(0.8)
        
        # Fade out for payment calculation
        self.play(
            *[FadeOut(mob) for mob in [step1_box, step1_title, sw_calc, sw_no, decision]],
            run_time=0.6
        )
        
        # Step 2: Calculate VCG payments
        step2_title = Text("Step 2: Calculate VCG Payments", 
                          font_size=20, color=RED_3B1B, weight=BOLD)
        step2_title.shift(DOWN * 1.2)
        self.play(Write(step2_title), run_time=0.8)
        
        # Payment for Agent 1
        payment1_box = RoundedRectangle(
            width=10, height=1.8,
            corner_radius=0.12,
            color=BLUE_3B1B,
            fill_opacity=0.12,
            stroke_width=2
        )
        payment1_box.shift(DOWN * 2.5)
        
        payment1_text = VGroup(
            Text("Agent 1's payment:", font_size=14, color=BLUE_3B1B, weight=BOLD),
            Text("Without 1: SW = max($150 + $100 - $300, $0) = $0", 
                 font_size=12, color=BLUE_3B1B),
            Text("With 1: Others get $150 + $100 - $300 = -$50", 
                 font_size=12, color=BLUE_3B1B),
            MathTex(r"p_1 = \$0 - (-\$50) = \$50", font_size=18, color=BLUE_3B1B)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.15)
        payment1_text.move_to(payment1_box)
        
        self.play(Create(payment1_box), run_time=0.6)
        self.play(Write(payment1_text), run_time=1.8)
        
        self.wait(1)
        
        # Show all payments in a summary
        self.play(
            *[FadeOut(mob) for mob in [payment1_box, payment1_text]],
            run_time=0.5
        )
        
        summary_box = RoundedRectangle(
            width=11, height=2.2,
            corner_radius=0.15,
            color=GREEN_3B1B,
            fill_opacity=0.18,
            stroke_width=3
        )
        summary_box.shift(DOWN * 2.8)
        
        summary_title = Text("VCG Payments Summary:", 
                            font_size=18, color=GREEN_3B1B, weight=BOLD)
        summary_title.move_to(summary_box.get_center() + UP * 0.7)
        
        payments = VGroup(
            Text("• Agent 1 pays: $50", font_size=15, color=BLUE_3B1B),
            Text("• Agent 2 pays: $50", font_size=15, color=GREEN_3B1B),
            Text("• Agent 3 pays: $50", font_size=15, color=ORANGE_3B1B),
            Line(LEFT * 2, RIGHT * 2, color=WHITE, stroke_width=1.5),
            Text("Total collected: $150 = Project cost: $300 - $150", 
                 font_size=14, color=YELLOW_3B1B, weight=BOLD)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.2)
        payments.move_to(summary_box.get_center() + DOWN * 0.3)
        
        self.play(
            Create(summary_box),
            Write(summary_title),
            run_time=0.8
        )
        self.play(Write(payments), run_time=1.8)
        
        # Highlight key insight
        insight = Text("Each pays their 'pivotal' contribution!", 
                      font_size=13, color=YELLOW_3B1B, weight=BOLD)
        insight.next_to(summary_box, DOWN, buff=0.25)
        self.play(
            Write(insight),
            Flash(insight, color=YELLOW_3B1B, flash_radius=0.6),
            run_time=0.9
        )
        
        self.wait(2)