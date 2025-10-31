from manim import *

class VCGPaymentRule(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("VCG Payment Rule (Clarke Pivot Rule)", 
                    font_size=32, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1.2)
        self.wait(0.5)
        
        # Key Idea
        key_idea = Text("Key Idea: Agent pays the HARM they cause to others", 
                       font_size=20, color=YELLOW_3B1B, weight=BOLD)
        key_idea.shift(UP * 2.3)
        self.play(Write(key_idea), run_time=1)
        self.wait(0.5)
        
        # Step 1: Define what others get WITH agent i
        step1_box = RoundedRectangle(
            width=11, height=1.8,
            corner_radius=0.15,
            color=GREEN_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        step1_box.shift(UP * 0.8)
        
        step1_num = Text("1", font_size=24, color=WHITE, weight=BOLD)
        step1_num.move_to(step1_box.get_left() + RIGHT * 0.4)
        
        step1_title = Text("Others' welfare WITH agent i:", 
                          font_size=16, color=GREEN_3B1B, weight=BOLD)
        step1_title.next_to(step1_num, RIGHT, buff=0.3).shift(UP * 0.4)
        
        step1_formula = MathTex(
            r"W_{-i}^{\text{with}} = \sum_{j \neq i} v_j(f(v_1, \ldots, v_n))",
            font_size=24,
            color=GREEN_3B1B
        )
        step1_formula.move_to(step1_box.get_center() + DOWN * 0.3)
        
        self.play(Create(step1_box), run_time=0.7)
        self.play(
            Write(step1_num),
            Write(step1_title),
            run_time=0.7
        )
        self.play(Write(step1_formula), run_time=1)
        
        self.wait(0.7)
        
        # Step 2: Define what others would get WITHOUT agent i
        step2_box = RoundedRectangle(
            width=11, height=1.8,
            corner_radius=0.15,
            color=ORANGE_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        step2_box.shift(DOWN * 1.2)
        
        step2_num = Text("2", font_size=24, color=WHITE, weight=BOLD)
        step2_num.move_to(step2_box.get_left() + RIGHT * 0.4)
        
        step2_title = Text("Others' welfare WITHOUT agent i:", 
                          font_size=16, color=ORANGE_3B1B, weight=BOLD)
        step2_title.next_to(step2_num, RIGHT, buff=0.3).shift(UP * 0.4)
        
        step2_formula = MathTex(
            r"W_{-i}^{\text{without}} = \sum_{j \neq i} v_j(f(v_1, \ldots, v_{i-1}, 0, v_{i+1}, \ldots, v_n))",
            font_size=20,
            color=ORANGE_3B1B
        )
        step2_formula.move_to(step2_box.get_center() + DOWN * 0.3)
        
        self.play(Create(step2_box), run_time=0.7)
        self.play(
            Write(step2_num),
            Write(step2_title),
            run_time=0.7
        )
        self.play(Write(step2_formula), run_time=1.2)
        
        self.wait(0.7)
        
        # Step 3: Payment is the difference
        step3_box = RoundedRectangle(
            width=11, height=2,
            corner_radius=0.15,
            color=RED_3B1B,
            fill_opacity=0.2,
            stroke_width=4
        )
        step3_box.shift(DOWN * 3.5)
        
        step3_num = Text("3", font_size=24, color=WHITE, weight=BOLD)
        step3_num.move_to(step3_box.get_left() + RIGHT * 0.4)
        
        step3_title = Text("Agent i's VCG Payment:", 
                          font_size=18, color=RED_3B1B, weight=BOLD)
        step3_title.next_to(step3_num, RIGHT, buff=0.3).shift(UP * 0.5)
        
        step3_formula = MathTex(
            r"p_i = W_{-i}^{\text{without}} - W_{-i}^{\text{with}}",
            font_size=28,
            color=RED_3B1B
        )
        step3_formula.move_to(step3_box.get_center() + DOWN * 0.1)
        
        step3_desc = Text("= Loss in others' welfare due to i's presence", 
                         font_size=14, color=RED_3B1B)
        step3_desc.next_to(step3_formula, DOWN, buff=0.25)
        
        self.play(
            Create(step3_box),
            Flash(step3_box, color=RED_3B1B, flash_radius=1.5),
            run_time=0.9
        )
        self.play(
            Write(step3_num),
            Write(step3_title),
            run_time=0.7
        )
        self.play(Write(step3_formula), run_time=1.2)
        self.play(Write(step3_desc), run_time=0.9)
        
        self.wait(1)
        
        # Fade out for interpretation
        self.play(
            *[FadeOut(mob) for mob in [step1_box, step1_num, step1_title, step1_formula,
                                       step2_box, step2_num, step2_title, step2_formula,
                                       step3_box, step3_num, step3_title, step3_formula, step3_desc]],
            run_time=0.7
        )
        
        # Interpretation
        interp_title = Text("Interpretation", font_size=24, color=PURPLE_3B1B, weight=BOLD)
        interp_title.shift(UP * 1.5)
        self.play(Write(interp_title), run_time=0.8)
        
        interp_points = VGroup(
            Text("• If agent i HELPS others → payment is NEGATIVE (i gets paid!)", 
                 font_size=15, color=GREEN_3B1B),
            Text("• If agent i HURTS others → payment is POSITIVE (i pays)", 
                 font_size=15, color=RED_3B1B),
            Text("• If agent i has NO EFFECT → payment is ZERO", 
                 font_size=15, color=BLUE_3B1B),
            Text("• Payment depends ONLY on others' valuations", 
                 font_size=15, color=PURPLE_3B1B, weight=BOLD),
            Text("  (not on i's own reported valuation!)", 
                 font_size=13, color=PURPLE_3B1B)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.35)
        interp_points.shift(DOWN * 0.3)
        
        for point in interp_points:
            self.play(Write(point), run_time=0.9)
            self.wait(0.3)
        
        self.wait(0.5)

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # Key insight box
        insight_box = Rectangle(
            width=11, height=1,
            color=YELLOW_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        insight_box.to_edge(DOWN, buff=0.3)
        
        insight_text = Text(
            "This payment rule makes truthful reporting a DOMINANT STRATEGY!",
            font_size=15,
            color=YELLOW_3B1B,
            weight=BOLD
        )
        insight_text.move_to(insight_box)
        
        self.play(
            Create(insight_box),
            Write(insight_text),
            Flash(insight_box, color=YELLOW_3B1B, flash_radius=1.2),
            run_time=1.3
        )
        
        self.wait(2)