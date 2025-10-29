from manim import *

class VCGTruthfulness(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("Why VCG is Truthful (Incentive Compatible)", 
                    font_size=32, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1.2)
        self.wait(0.5)
        
        # Question
        question = Text("Why should Alice bid her TRUE value?", 
                       font_size=20, color=YELLOW_3B1B)
        question.shift(UP * 2.3)
        self.play(Write(question), run_time=0.8)
        self.wait(0.5)
        
        # Alice's true valuation
        true_val_box = RoundedRectangle(
            width=4, height=1,
            corner_radius=0.12,
            color=BLUE_3B1B,
            fill_opacity=0.2,
            stroke_width=3
        )
        true_val_box.shift(UP * 1.2)
        
        true_val_text = VGroup(
            Text("Alice's TRUE value:", font_size=16, color=BLUE_3B1B),
            Text("$100", font_size=22, color=BLUE_3B1B, weight=BOLD)
        ).arrange(DOWN, buff=0.2)
        true_val_text.move_to(true_val_box)
        
        self.play(
            Create(true_val_box),
            Write(true_val_text),
            run_time=0.9
        )
        self.wait(0.5)
        
        # Scenario comparison
        divider = Line(UP * 0.3, DOWN * 3.5, color=WHITE, stroke_width=2)
        divider.move_to(ORIGIN)
        self.play(Create(divider), run_time=0.6)
        
        # LEFT SIDE: Truthful bidding
        truth_label = Text("Strategy 1: Bid Truthfully", 
                          font_size=18, color=GREEN_3B1B, weight=BOLD)
        truth_label.shift(LEFT * 3 + UP * 0.2)
        self.play(Write(truth_label), run_time=0.7)
        
        truth_bid = VGroup(
            Text("Alice bids:", font_size=14, color=GREEN_3B1B),
            Text("$100", font_size=20, color=GREEN_3B1B, weight=BOLD)
        ).arrange(DOWN, buff=0.15)
        truth_bid.shift(LEFT * 3 + DOWN * 0.5)
        
        self.play(Write(truth_bid), run_time=0.6)
        
        # Outcome for truthful bidding
        truth_outcome_box = RoundedRectangle(
            width=3, height=2,
            corner_radius=0.12,
            color=GREEN_3B1B,
            fill_opacity=0.15,
            stroke_width=2
        )
        truth_outcome_box.shift(LEFT * 3 + DOWN * 2)
        
        truth_outcome = VGroup(
            Text("Wins item!", font_size=14, color=GREEN_3B1B, weight=BOLD),
            Text("Pays: $80", font_size=14, color=GREEN_3B1B),
            Line(LEFT * 1, RIGHT * 1, color=GREEN_3B1B, stroke_width=1),
            Text("Utility:", font_size=12, color=GREEN_3B1B),
            Text("$100 - $80 = $20", font_size=16, color=GREEN_3B1B, weight=BOLD)
        ).arrange(DOWN, buff=0.15)
        truth_outcome.move_to(truth_outcome_box)
        
        self.play(Create(truth_outcome_box), run_time=0.5)
        self.play(Write(truth_outcome), run_time=1.2)
        
        # Checkmark for good outcome
        checkmark = Text("✓", font_size=36, color=GREEN_3B1B, weight=BOLD)
        checkmark.next_to(truth_outcome_box, DOWN, buff=0.3)
        self.play(FadeIn(checkmark, scale=1.5), run_time=0.5)
        
        self.wait(0.8)
        
        # RIGHT SIDE: Lying (bidding lower)
        lie_label = Text("Strategy 2: Bid Lower", 
                        font_size=18, color=RED_3B1B, weight=BOLD)
        lie_label.shift(RIGHT * 3 + UP * 0.2)
        self.play(Write(lie_label), run_time=0.7)
        
        lie_bid = VGroup(
            Text("Alice bids:", font_size=14, color=RED_3B1B),
            Text("$75", font_size=20, color=RED_3B1B, weight=BOLD),
            Text("(lying!)", font_size=11, color=RED_3B1B)
        ).arrange(DOWN, buff=0.15)
        lie_bid.shift(RIGHT * 3 + DOWN * 0.5)
        
        self.play(Write(lie_bid), run_time=0.6)
        
        # Outcome for lying
        lie_outcome_box = RoundedRectangle(
            width=3, height=2,
            corner_radius=0.12,
            color=RED_3B1B,
            fill_opacity=0.15,
            stroke_width=2
        )
        lie_outcome_box.shift(RIGHT * 3 + DOWN * 2)
        
        lie_outcome = VGroup(
            Text("LOSES!", font_size=16, color=RED_3B1B, weight=BOLD),
            Text("Bob wins", font_size=12, color=RED_3B1B),
            Text("(bid $80)", font_size=11, color=RED_3B1B),
            Line(LEFT * 1, RIGHT * 1, color=RED_3B1B, stroke_width=1),
            Text("Utility:", font_size=12, color=RED_3B1B),
            Text("$0", font_size=18, color=RED_3B1B, weight=BOLD)
        ).arrange(DOWN, buff=0.15)
        lie_outcome.move_to(lie_outcome_box)
        
        self.play(Create(lie_outcome_box), run_time=0.5)
        self.play(
            Write(lie_outcome),
            Flash(lie_outcome_box, color=RED_3B1B, flash_radius=1.0),
            run_time=1.2
        )
        
        # X mark for bad outcome
        xmark = VGroup(
            Line(UP * 0.3 + LEFT * 0.3, DOWN * 0.3 + RIGHT * 0.3, 
                 color=RED_3B1B, stroke_width=4),
            Line(UP * 0.3 + RIGHT * 0.3, DOWN * 0.3 + LEFT * 0.3, 
                 color=RED_3B1B, stroke_width=4)
        )
        xmark.next_to(lie_outcome_box, DOWN, buff=0.3)
        self.play(Create(xmark), run_time=0.5)
        
        self.wait(1)
        
        # Comparison arrow
        comparison_arrow = DoubleArrow(
            start=truth_outcome_box.get_right(),
            end=lie_outcome_box.get_left(),
            color=YELLOW_3B1B,
            stroke_width=3,
            tip_length=0.25
        )
        comparison_arrow.shift(DOWN * 0.5)
        
        comparison_text = Text("$20 > $0", font_size=18, color=YELLOW_3B1B, weight=BOLD)
        comparison_text.next_to(comparison_arrow, UP, buff=0.2)
        
        self.play(
            GrowArrow(comparison_arrow),
            Write(comparison_text),
            run_time=0.9
        )
        
        self.wait(0.8)
        
        # Fade out for conclusion
        self.play(
            *[FadeOut(mob) for mob in [divider, truth_label, truth_bid, truth_outcome_box, 
                                       truth_outcome, checkmark, lie_label, lie_bid, 
                                       lie_outcome_box, lie_outcome, xmark, 
                                       comparison_arrow, comparison_text]],
            run_time=0.7
        )
        
        # Key insight
        insight_box = RoundedRectangle(
            width=11, height=3,
            corner_radius=0.2,
            color=PURPLE_3B1B,
            fill_opacity=0.2,
            stroke_width=4
        )
        insight_box.shift(DOWN * 0.5)
        
        insight_title = Text("Key Insight: Dominant Strategy", 
                            font_size=22, color=PURPLE_3B1B, weight=BOLD)
        insight_title.next_to(insight_box, UP, buff=0.3)
        
        insight_text = VGroup(
            Text("• Bidding TRUE value is a DOMINANT strategy", 
                 font_size=16, color=PURPLE_3B1B),
            Text("• Payment is INDEPENDENT of your bid", 
                 font_size=16, color=PURPLE_3B1B),
            Text("  (depends only on others' bids)", 
                 font_size=14, color=PURPLE_3B1B),
            Text("• Lying can only make you WORSE OFF", 
                 font_size=16, color=PURPLE_3B1B),
            Text("• This ensures EFFICIENT allocation", 
                 font_size=16, color=PURPLE_3B1B)
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.25)
        insight_text.move_to(insight_box)
        
        self.play(
            Create(insight_box),
            Write(insight_title),
            run_time=1
        )
        self.play(
            *[Write(line) for line in insight_text],
            run_time=2,
            lag_ratio=0.3
        )
        
        self.wait(0.5)
        
        # Formula at bottom
        formula_box = Rectangle(
            width=11, height=0.9,
            color=BLUE_3B1B,
            fill_opacity=0.1,
            stroke_width=2
        )
        formula_box.to_edge(DOWN, buff=0.3)
        
        formula = MathTex(
            r"\text{Payment}_i = \max_{j \neq i} \text{Bid}_j",
            font_size=28,
            color=BLUE_3B1B
        )
        formula.move_to(formula_box)
        
        formula_label = Text("VCG Payment Rule", font_size=14, color=BLUE_3B1B)
        formula_label.next_to(formula_box, UP, buff=0.1)
        
        self.play(
            Create(formula_box),
            Write(formula_label),
            Write(formula),
            run_time=1.2
        )
        
        self.wait(2)