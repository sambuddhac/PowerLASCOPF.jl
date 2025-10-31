from manim import *

class RenewablePenetration(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("Enhancing Renewable Penetration Scheme", font_size=28, color=BLUE_3B1B)
        title.to_edge(UP)
        self.play(Write(title), run_time=1)
        self.wait(0.5)
        
        # ISO / LASCOPF Central box
        iso_box = RoundedRectangle(
            width=3.5, height=2,
            corner_radius=0.2,
            color=BLUE_3B1B,
            fill_opacity=0.25,
            stroke_width=4
        )
        iso_box.move_to(ORIGIN)
        
        iso_label = Text("ISO", font_size=20, color=BLUE_3B1B, weight=BOLD)
        iso_label.move_to(iso_box.get_center() + UP * 0.6)
        
        lascopf_label = Text("LASCOPF\nOptimizer", font_size=14, color=BLUE_3B1B)
        lascopf_label.move_to(iso_box.get_center() + DOWN * 0.3)
        
        self.play(Create(iso_box), run_time=0.8)
        self.play(Write(iso_label), Write(lascopf_label), run_time=0.8)
        self.wait(0.5)
        
        # Transmission Layer (Top)
        trans_layer = Rectangle(
            width=12, height=1.2,
            color=YELLOW_3B1B,
            fill_opacity=0.15,
            stroke_width=2
        )
        trans_layer.shift(UP * 2.8)
        
        trans_label = Text("Transmission Network & Wholesale Market", font_size=14, color=YELLOW_3B1B, weight=BOLD)
        trans_label.move_to(trans_layer)
        
        self.play(Create(trans_layer), Write(trans_label), run_time=0.8)
        self.wait(0.3)
        
        # Distribution/Retail Layer (Bottom)
        dist_layer = Rectangle(
            width=12, height=1.2,
            color=GREEN_3B1B,
            fill_opacity=0.15,
            stroke_width=2
        )
        dist_layer.shift(DOWN * 2.8)
        
        dist_label = Text("Distribution Network & Retail Market", font_size=14, color=GREEN_3B1B, weight=BOLD)
        dist_label.move_to(dist_layer)
        
        self.play(Create(dist_layer), Write(dist_label), run_time=0.8)
        self.wait(0.5)
        
        # Wholesale resources (circles in transmission layer)
        wholesale_resources = [
            ("Conv.\nGen", LEFT * 4.5 + UP * 2.8, ORANGE_3B1B),
            ("Wind", LEFT * 2.5 + UP * 2.8, GREEN_3B1B),
            ("Solar\nPV", LEFT * 0.5 + UP * 2.8, YELLOW_3B1B),
            ("Other\nRenew", RIGHT * 1.5 + UP * 2.8, GREEN_3B1B),
        ]
        
        wholesale_circles = []
        for label, pos, color in wholesale_resources:
            circle = Circle(radius=0.4, color=color, fill_opacity=0.3, stroke_width=2)
            circle.move_to(pos)
            text = Text(label, font_size=9, color=color, weight=BOLD)
            text.move_to(circle)
            
            wholesale_circles.append((circle, text))
            self.play(Create(circle), Write(text), run_time=0.4)
        
        self.wait(0.3)
        
        # Retail resources (circles in distribution layer)
        retail_resources = [
            ("PEVs", LEFT * 5 + DOWN * 2.8, PURPLE_3B1B),
            ("Battery", LEFT * 3 + DOWN * 2.8, ORANGE_3B1B),
            ("Roof\nSolar", LEFT * 1 + DOWN * 2.8, YELLOW_3B1B),
            ("Conv.\nLoad", RIGHT * 1 + DOWN * 2.8, RED_3B1B),
        ]
        
        retail_circles = []
        for label, pos, color in retail_resources:
            circle = Circle(radius=0.4, color=color, fill_opacity=0.3, stroke_width=2)
            circle.move_to(pos)
            text = Text(label, font_size=9, color=color, weight=BOLD)
            text.move_to(circle)
            
            retail_circles.append((circle, text))
            self.play(Create(circle), Write(text), run_time=0.4)
        
        self.wait(0.5)
        
        # Aggregator (optional - dashed box)
        aggregator_box = DashedVMobject(
            RoundedRectangle(
                width=2, height=1,
                corner_radius=0.15,
                color=PURPLE_3B1B,
                stroke_width=2
            ),
            num_dashes=15
        )
        aggregator_box.move_to(RIGHT * 4 + DOWN * 1.5)
        
        agg_label = Text("Aggregator", font_size=11, color=PURPLE_3B1B)
        agg_label.move_to(aggregator_box)
        
        self.play(Create(aggregator_box), Write(agg_label), run_time=0.6)
        self.wait(0.3)
        
        # Arrows from wholesale to ISO (Bids/Offers)
        for i, (circle, _) in enumerate(wholesale_circles):
            arrow = Arrow(
                start=circle.get_bottom(),
                end=iso_box.get_top() + LEFT * (2 - i * 1.5),
                color=BLUE_3B1B,
                stroke_width=2,
                tip_length=0.15
            )
            self.play(Create(arrow), run_time=0.3)
        
        bid_label = Text("Bids/Offers", font_size=10, color=BLUE_3B1B)
        bid_label.move_to(LEFT * 3 + UP * 1.5)
        self.play(FadeIn(bid_label, scale=0.6), run_time=0.4)
        
        self.wait(0.3)
        
        # Arrows from retail to ISO (through aggregator for some)
        for i, (circle, _) in enumerate(retail_circles[:3]):
            # To aggregator first
            arrow1 = Arrow(
                start=circle.get_top(),
                end=aggregator_box.get_bottom() + LEFT * (1 - i * 0.8),
                color=GREEN_3B1B,
                stroke_width=1.5,
                tip_length=0.12
            )
            self.play(Create(arrow1), run_time=0.25)
        
        # From aggregator to ISO
        agg_to_iso = Arrow(
            start=aggregator_box.get_left(),
            end=iso_box.get_right() + DOWN * 0.3,
            color=GREEN_3B1B,
            stroke_width=2,
            tip_length=0.15
        )
        self.play(Create(agg_to_iso), run_time=0.5)
        
        offer_label = Text("Bids/Offers", font_size=10, color=GREEN_3B1B)
        offer_label.move_to(RIGHT * 2.5 + DOWN * 0.8)
        self.play(FadeIn(offer_label, scale=0.6), run_time=0.4)
        
        self.wait(0.5)
        
        # Pricing signals FROM ISO (curved arrows)
        price_arrow1 = CurvedArrow(
            start_point=iso_box.get_top() + RIGHT * 0.5,
            end_point=trans_layer.get_center() + RIGHT * 3,
            color=RED_3B1B,
            stroke_width=2.5,
            tip_length=0.2,
            angle=-TAU/8
        )
        
        price_label1 = Text("Prices/\nIncentives", font_size=10, color=RED_3B1B, weight=BOLD)
        price_label1.next_to(price_arrow1, RIGHT, buff=0.1)
        
        self.play(Create(price_arrow1), run_time=0.7)
        self.play(FadeIn(price_label1, scale=0.6), run_time=0.4)
        
        price_arrow2 = CurvedArrow(
            start_point=iso_box.get_bottom() + RIGHT * 0.5,
            end_point=dist_layer.get_center() + RIGHT * 3,
            color=RED_3B1B,
            stroke_width=2.5,
            tip_length=0.2,
            angle=TAU/8
        )
        
        price_label2 = Text("Prices/\nIncentives", font_size=10, color=RED_3B1B, weight=BOLD)
        price_label2.next_to(price_arrow2, RIGHT, buff=0.1)
        
        self.play(Create(price_arrow2), run_time=0.7)
        self.play(FadeIn(price_label2, scale=0.6), run_time=0.4)
        
        self.wait(0.5)
        
        # Control/Execution signals (dashed arrows)
        for i, (circle, _) in enumerate(wholesale_circles[:2]):
            exec_arrow = DashedVMobject(
                Arrow(
                    start=iso_box.get_top() + LEFT * (1.5 - i),
                    end=circle.get_bottom() + UP * 0.1,
                    color=ORANGE_3B1B,
                    stroke_width=1.5,
                    tip_length=0.12
                ),
                num_dashes=10
            )
            self.play(Create(exec_arrow), run_time=0.3)
        
        exec_label = Text("Control\nSignals", font_size=9, color=ORANGE_3B1B)
        exec_label.move_to(LEFT * 2 + UP * 1.8)
        self.play(FadeIn(exec_label, scale=0.5), run_time=0.3)
        
        self.wait(0.5)
        
        # Legend box
        legend_box = Rectangle(
            width=3, height=1.8,
            color=WHITE,
            fill_opacity=0.05,
            stroke_width=1
        )
        legend_box.to_corner(DR, buff=0.3)
        
        legend_title = Text("Legend", font_size=12, color=WHITE, weight=BOLD)
        legend_title.next_to(legend_box, UP, buff=0.1, aligned_edge=LEFT)
        
        # Legend items
        legend_items = VGroup()
        
        item1 = VGroup(
            Line(LEFT * 0.3, RIGHT * 0.3, color=BLUE_3B1B, stroke_width=2),
            Text("Bids/Offers", font_size=8, color=WHITE)
        ).arrange(RIGHT, buff=0.15)
        
        item2 = VGroup(
            Line(LEFT * 0.3, RIGHT * 0.3, color=RED_3B1B, stroke_width=2),
            Text("Pricing Signals", font_size=8, color=WHITE)
        ).arrange(RIGHT, buff=0.15)
        
        item3 = VGroup(
            DashedVMobject(Line(LEFT * 0.3, RIGHT * 0.3, stroke_width=2), num_dashes=5),
            Text("Control Signals", font_size=8, color=WHITE)
        ).arrange(RIGHT, buff=0.15)
        
        legend_items.add(item1, item2, item3)
        legend_items.arrange(DOWN, aligned_edge=LEFT, buff=0.15)
        legend_items.move_to(legend_box)
        
        self.play(
            Create(legend_box),
            Write(legend_title),
            run_time=0.6
        )
        self.play(
            *[Write(item) for item in legend_items],
            run_time=0.8
        )
        
        self.wait(0.5)

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        # Highlight renewable penetration enhancement
        renewable_highlight = Ellipse(
            width=5, height=2,
            color=GREEN_3B1B,
            stroke_width=3
        )
        renewable_highlight.move_to(UP * 2.8 + LEFT * 1.5)
        
        enhancement_text = Text(
            "Enhanced Renewable\nParticipation",
            font_size=12,
            color=GREEN_3B1B,
            weight=BOLD
        )
        enhancement_text.next_to(renewable_highlight, UP, buff=0.2)
        
        self.play(
            Create(renewable_highlight),
            Flash(renewable_highlight, color=GREEN_3B1B, flash_radius=1.5),
            run_time=1
        )
        self.play(Write(enhancement_text), run_time=0.8)
        
        self.wait(2)