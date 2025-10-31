from manim import *

class VCGGeneral(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("General VCG Mechanism Principle", 
                    font_size=36, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1.2)
        self.wait(0.5)
        
        # Core principle
        principle_text = Text("Core Principle: Each agent pays the EXTERNALITY they impose", 
                             font_size=18, color=YELLOW_3B1B, weight=BOLD)
        principle_text.shift(UP * 2.3)
        self.play(Write(principle_text), run_time=1)
        self.wait(0.5)
        
        # Social welfare concept
        sw_box = RoundedRectangle(
            width=10, height=1.2,
            corner_radius=0.15,
            color=GREEN_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        sw_box.shift(UP * 1.2)
        
        sw_text = Text("Social Welfare = Total value created for all participants", 
                      font_size=16, color=GREEN_3B1B)
        sw_text.move_to(sw_box)
        
        self.play(
            Create(sw_box),
            Write(sw_text),
            run_time=1
        )
        self.wait(0.5)
        
        # Payment calculation steps
        step_y = 0
        
        # Step 1: Calculate social welfare WITH agent i
        step1_box = RoundedRectangle(
            width=11, height=1.5,
            corner_radius=0.12,
            color=BLUE_3B1B,
            fill_opacity=0.12,
            stroke_width=2
        )
        step1_box.shift(UP * step_y)
        
        step1_title = Text("Step 1: Social Welfare WITH agent i", 
                          font_size=16, color=BLUE_3B1B, weight=BOLD)
        step1_title.move_to(step1_box.get_center() + UP * 0.5)
        
        step1_formula = MathTex(
            r"SW_{\text{with } i} = \sum_{j} v_j \cdot x_j",
            font_size=24,
            color=BLUE_3B1B
        )
        step1_formula.move_to(step1_box.get_center() + DOWN * 0.3)
        
        step1_desc = Text("(optimal allocation including i)", 
                         font_size=12, color=BLUE_3B1B)
        step1_desc.next_to(step1_formula, DOWN, buff=0.15)
        
        self.play(Create(step1_box), run_time=0.6)
        self.play(
            Write(step1_title),
            Write(step1_formula),
            Write(step1_desc),
            run_time=1
        )
        self.wait(0.5)
        
        # Step 2: Calculate social welfare WITHOUT agent i
        step2_box = RoundedRectangle(
            width=11, height=1.5,
            corner_radius=0.12,
            color=ORANGE_3B1B,
            fill_opacity=0.12,
            stroke_width=2
        )
        step2_box.shift(DOWN * 1.8)
        
        step2_title = Text("Step 2: Social Welfare WITHOUT agent i", 
                          font_size=16, color=ORANGE_3B1B, weight=BOLD)
        step2_title.move_to(step2_box.get_center() + UP * 0.5)
        
        step2_formula = MathTex(
            r"SW_{\text{without } i} = \sum_{j \neq i} v_j \cdot x_j^{-i}",
            font_size=24,
            color=ORANGE_3B1B
        )
        step2_formula.move_to(step2_box.get_center() + DOWN * 0.3)
        
        step2_desc = Text("(optimal allocation excluding i)", 
                         font_size=12, color=ORANGE_3B1B)
        step2_desc.next_to(step2_formula, DOWN, buff=0.15)
        
        self.play(Create(step2_box), run_time=0.6)
        self.play(
            Write(step2_title),
            Write(step2_formula),
            Write(step2_desc),
            run_time=1
        )
        self.wait(0.5)
        
        # Step 3: Payment is the difference
        step3_box = RoundedRectangle(
            width=11, height=1.8,
            corner_radius=0.12,
            color=RED_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        step3_box.shift(DOWN * 3.8)
        
        step3_title = Text("Step 3: Agent i's VCG Payment", 
                          font_size=18, color=RED_3B1B, weight=BOLD)
        step3_title.move_to(step3_box.get_center() + UP * 0.6)
        
        step3_formula = MathTex(
            r"\text{Payment}_i = SW_{\text{without } i} - \left(SW_{\text{with } i} - v_i \cdot x_i\right)",
            font_size=22,
            color=RED_3B1B
        )
        step3_formula.move_to(step3_box.get_center() + DOWN * 0.1)
        
        step3_desc = Text("= Social cost imposed by i's presence", 
                         font_size=14, color=RED_3B1B, weight=BOLD)
        step3_desc.next_to(step3_formula, DOWN, buff=0.2)
        
        self.play(
            Create(step3_box),
            Flash(step3_box, color=RED_3B1B, flash_radius=1.5),
            run_time=0.8
        )
        self.play(
            Write(step3_title),
            Write(step3_formula),
            run_time=1.2
        )
        self.play(Write(step3_desc), run_time=0.8)
        
        self.wait(1)
        
        # Fade out for properties
        self.play(
            *[FadeOut(mob) for mob in [step1_box, step1_title, step1_formula, step1_desc,
                                       step2_box, step2_title, step2_formula, step2_desc,
                                       step3_box, step3_title, step3_formula, step3_desc]],
            run_time=0.8
        )
        
        # Key properties
        properties_title = Text("VCG Properties", font_size=24, color=PURPLE_3B1B, weight=BOLD)
        properties_title.shift(UP * 1.5)
        self.play(Write(properties_title), run_time=0.8)
        
        properties = VGroup(
            VGroup(
                Circle(radius=0.15, color=GREEN_3B1B, fill_opacity=0.5, stroke_width=0),
                Text("Truthful (Incentive Compatible)", font_size=16, color=GREEN_3B1B, weight=BOLD)
            ).arrange(RIGHT, buff=0.3),
            
            VGroup(
                Circle(radius=0.15, color=BLUE_3B1B, fill_opacity=0.5, stroke_width=0),
                Text("Efficient (Maximizes Social Welfare)", font_size=16, color=BLUE_3B1B, weight=BOLD)
            ).arrange(RIGHT, buff=0.3),
            
            VGroup(
                Circle(radius=0.15, color=ORANGE_3B1B, fill_opacity=0.5, stroke_width=0),
                Text("Individual Rationality", font_size=16, color=ORANGE_3B1B, weight=BOLD)
            ).arrange(RIGHT, buff=0.3),
            
            VGroup(
                Circle(radius=0.15, color=YELLOW_3B1B, fill_opacity=0.5, stroke_width=0),
                Text("No Positive Transfers (agents pay, don't receive)", font_size=15, color=YELLOW_3B1B, weight=BOLD)
            ).arrange(RIGHT, buff=0.3)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.4)
        properties.shift(DOWN * 0.3)
        
        for prop in properties:
            self.play(
                FadeIn(prop[0], scale=1.5),
                Write(prop[1]),
                run_time=0.8
            )
            self.wait(0.3)
        
        self.wait(0.5)

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # Applications box
        app_box = RoundedRectangle(
            width=11, height=1.2,
            corner_radius=0.15,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=2
        )
        app_box.to_edge(DOWN, buff=0.3)
        
        app_title = Text("Applications", font_size=16, color=BLUE_3B1B, weight=BOLD)
        app_title.next_to(app_box.get_top(), DOWN, buff=0.15)
        
        app_text = Text(
            "Spectrum auctions • Online advertising • Resource allocation • Electricity markets",
            font_size=13,
            color=BLUE_3B1B
        )
        app_text.move_to(app_box.get_center() + DOWN * 0.15)
        
        self.play(
            Create(app_box),
            Write(app_title),
            Write(app_text),
            run_time=1.2
        )
        
        self.wait(2)