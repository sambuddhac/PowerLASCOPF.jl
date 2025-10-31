from manim import *

class VCGDefinition(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("VCG Mechanism: General Definition", 
                    font_size=36, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1.2)
        self.wait(0.5)
        
        # Problem Setup
        setup_title = Text("Social Choice Problem Setup", 
                          font_size=24, color=YELLOW_3B1B, weight=BOLD)
        setup_title.shift(UP * 2.3)
        self.play(Write(setup_title), run_time=0.8)
        self.wait(0.3)
        
        # Set of agents
        agents_box = RoundedRectangle(
            width=5, height=0.9,
            corner_radius=0.12,
            color=GREEN_3B1B,
            fill_opacity=0.15,
            stroke_width=2
        )
        agents_box.shift(UP * 1.2 + LEFT * 3)
        
        agents_text = MathTex(
            r"\text{Agents: } N = \{1, 2, \ldots, n\}",
            font_size=20,
            color=GREEN_3B1B
        )
        agents_text.move_to(agents_box)
        
        self.play(
            Create(agents_box),
            Write(agents_text),
            run_time=0.8
        )
        
        # Set of outcomes
        outcomes_box = RoundedRectangle(
            width=5, height=0.9,
            corner_radius=0.12,
            color=ORANGE_3B1B,
            fill_opacity=0.15,
            stroke_width=2
        )
        outcomes_box.shift(UP * 1.2 + RIGHT * 3)
        
        outcomes_text = MathTex(
            r"\text{Outcomes: } \Omega",
            font_size=20,
            color=ORANGE_3B1B
        )
        outcomes_text.move_to(outcomes_box)
        
        self.play(
            Create(outcomes_box),
            Write(outcomes_text),
            run_time=0.8
        )
        
        self.wait(0.5)
        
        # Valuation functions
        val_title = Text("Each agent i has a valuation function:", 
                        font_size=16, color=BLUE_3B1B)
        val_title.shift(UP * 0.3)
        self.play(Write(val_title), run_time=0.7)
        
        val_formula = MathTex(
            r"v_i : \Omega \to \mathbb{R}",
            font_size=32,
            color=BLUE_3B1B
        )
        val_formula.shift(DOWN * 0.3)
        
        self.play(Write(val_formula), run_time=0.9)
        
        val_desc = Text("(how much agent i values each outcome)", 
                       font_size=14, color=BLUE_3B1B)
        val_desc.next_to(val_formula, DOWN, buff=0.3)
        self.play(FadeIn(val_desc, scale=0.8), run_time=0.6)
        
        self.wait(0.8)
        
        # Social choice function
        self.play(
            *[FadeOut(mob) for mob in [val_title, val_formula, val_desc]],
            run_time=0.5
        )
        
        scf_box = RoundedRectangle(
            width=10, height=2.5,
            corner_radius=0.15,
            color=PURPLE_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        scf_box.shift(DOWN * 0.3)
        
        scf_title = Text("Social Choice Function", 
                        font_size=20, color=PURPLE_3B1B, weight=BOLD)
        scf_title.next_to(scf_box, UP, buff=0.2)
        
        scf_formula = MathTex(
            r"f : \mathbb{R}^n \to \Omega",
            font_size=28,
            color=PURPLE_3B1B
        )
        scf_formula.move_to(scf_box.get_center() + UP * 0.5)
        
        scf_desc = VGroup(
            Text("Takes reported valuations (v₁, v₂, ..., vₙ)", 
                 font_size=14, color=PURPLE_3B1B),
            Text("Returns chosen outcome ω ∈ Ω", 
                 font_size=14, color=PURPLE_3B1B)
        ).arrange(DOWN, buff=0.2)
        scf_desc.move_to(scf_box.get_center() + DOWN * 0.4)
        
        self.play(
            Create(scf_box),
            Write(scf_title),
            run_time=0.8
        )
        self.play(
            Write(scf_formula),
            Write(scf_desc),
            run_time=1.2
        )
        
        self.wait(0.8)
        
        # Goal: Efficiency
        self.play(
            *[FadeOut(mob) for mob in [scf_box, scf_title, scf_formula, scf_desc]],
            run_time=0.6
        )
        
        goal_box = RoundedRectangle(
            width=11, height=2.8,
            corner_radius=0.18,
            color=GREEN_3B1B,
            fill_opacity=0.2,
            stroke_width=4
        )
        goal_box.shift(DOWN * 0.5)
        
        goal_title = Text("Goal: Maximize Social Welfare", 
                         font_size=22, color=GREEN_3B1B, weight=BOLD)
        goal_title.next_to(goal_box, UP, buff=0.25)
        
        goal_formula = MathTex(
            r"f(v_1, \ldots, v_n) = \arg\max_{\omega \in \Omega} \sum_{i=1}^n v_i(\omega)",
            font_size=26,
            color=GREEN_3B1B
        )
        goal_formula.move_to(goal_box.get_center() + UP * 0.4)
        
        goal_desc = Text("Choose outcome that maximizes total value", 
                        font_size=16, color=GREEN_3B1B)
        goal_desc.move_to(goal_box.get_center() + DOWN * 0.5)
        
        self.play(
            Create(goal_box),
            Flash(goal_box, color=GREEN_3B1B, flash_radius=1.5),
            run_time=0.9
        )
        self.play(
            Write(goal_title),
            Write(goal_formula),
            run_time=1.3
        )
        self.play(Write(goal_desc), run_time=0.8)
        
        self.wait(0.5)

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # Challenge
        challenge_box = Rectangle(
            width=11, height=0.9,
            color=RED_3B1B,
            fill_opacity=0.15,
            stroke_width=2
        )
        challenge_box.to_edge(DOWN, buff=0.3)
        
        challenge_text = Text(
            "Challenge: How do we get agents to report TRUE valuations?",
            font_size=15,
            color=RED_3B1B,
            weight=BOLD
        )
        challenge_text.move_to(challenge_box)
        
        self.play(
            Create(challenge_box),
            Write(challenge_text),
            Flash(challenge_box, color=RED_3B1B, flash_radius=0.8),
            run_time=1.2
        )
        
        self.wait(2)