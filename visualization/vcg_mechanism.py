from manim import *

class VCGMechanism(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("Vickrey-Clarke-Groves (VCG) Mechanism", font_size=36, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1.2)
        self.wait(0.5)
        
        # Subtitle
        subtitle = Text("Second-Price Sealed-Bid Auction", font_size=20, color=YELLOW_3B1B)
        subtitle.next_to(title, DOWN, buff=0.3)
        self.play(FadeIn(subtitle, scale=0.8), run_time=0.8)
        self.wait(0.5)
        
        # Scenario setup
        scenario_text = Text("Scenario: One item for sale", font_size=18, color=WHITE)
        scenario_text.shift(UP * 1.8)
        self.play(Write(scenario_text), run_time=0.8)
        
        # Item being auctioned
        item_box = RoundedRectangle(
            width=1.5, height=1.5,
            corner_radius=0.15,
            color=YELLOW_3B1B,
            fill_opacity=0.3,
            stroke_width=3
        )
        item_box.shift(UP * 0.5)
        
        item_label = Text("Item", font_size=16, color=YELLOW_3B1B, weight=BOLD)
        item_label.move_to(item_box)
        
        self.play(
            Create(item_box),
            Flash(item_box, color=YELLOW_3B1B, flash_radius=1.0),
            run_time=0.8
        )
        self.play(Write(item_label), run_time=0.6)
        self.wait(0.5)
        
        # Three bidders
        bidder_data = [
            ("Alice", LEFT * 4 + DOWN * 1, BLUE_3B1B, "$100"),
            ("Bob", ORIGIN + DOWN * 1, GREEN_3B1B, "$80"),
            ("Charlie", RIGHT * 4 + DOWN * 1, ORANGE_3B1B, "$70")
        ]
        
        bidders = []
        
        for name, pos, color, bid_val in bidder_data:
            # Bidder circle
            bidder = Circle(radius=0.6, color=color, fill_opacity=0.3, stroke_width=3)
            bidder.move_to(pos)
            
            bidder_name = Text(name, font_size=16, color=color, weight=BOLD)
            bidder_name.move_to(bidder)
            
            # Sealed bid (envelope)
            envelope = RoundedRectangle(
                width=1.2, height=0.6,
                corner_radius=0.08,
                color=color,
                fill_opacity=0.2,
                stroke_width=2
            )
            envelope.next_to(bidder, DOWN, buff=0.3)
            
            bid_text = Text("Sealed", font_size=10, color=color)
            bid_text.move_to(envelope)
            
            self.play(
                Create(bidder),
                Write(bidder_name),
                run_time=0.5
            )
            self.play(
                Create(envelope),
                Write(bid_text),
                run_time=0.4
            )
            
            bidders.append((bidder, bidder_name, envelope, bid_text, name, color, bid_val, pos))
        
        self.wait(0.5)
        
        # Step 1: Reveal bids
        step1 = Text("Step 1: Reveal Bids", font_size=20, color=YELLOW_3B1B, weight=BOLD)
        step1.to_edge(LEFT, buff=0.5).shift(UP * 2.5)
        
        self.play(Write(step1), run_time=0.8)
        
        revealed_bids = []
        
        for bidder, bidder_name, envelope, bid_text, name, color, bid_val, pos in bidders:
            # Open envelope animation
            self.play(
                envelope.animate.scale(1.2),
                bid_text.animate.scale(0.01),
                run_time=0.4
            )
            
            # Show bid value
            revealed_bid = Text(bid_val, font_size=18, color=color, weight=BOLD)
            revealed_bid.move_to(envelope)
            
            self.play(
                FadeOut(bid_text),
                FadeIn(revealed_bid, scale=1.5),
                Flash(revealed_bid, color=color, flash_radius=0.5),
                run_time=0.6
            )
            
            revealed_bids.append(revealed_bid)
        
        self.wait(0.8)
        
        # Step 2: Determine winner
        step2 = Text("Step 2: Highest Bid Wins", font_size=20, color=GREEN_3B1B, weight=BOLD)
        step2.next_to(step1, DOWN, buff=0.3, aligned_edge=LEFT)
        
        self.play(Write(step2), run_time=0.8)
        
        # Highlight Alice as winner
        alice_bidder, alice_name = bidders[0][0], bidders[0][1]
        
        winner_highlight = Circle(radius=0.8, color=GREEN_3B1B, stroke_width=5)
        winner_highlight.move_to(alice_bidder)
        
        winner_crown = Text("👑", font_size=40, color=YELLOW_3B1B)
        winner_crown.next_to(alice_bidder, UP, buff=0.2)
        
        self.play(
            Create(winner_highlight),
            FadeIn(winner_crown, scale=2),
            Flash(alice_bidder, color=GREEN_3B1B, flash_radius=1.2),
            run_time=1
        )
        
        winner_text = Text("Winner!", font_size=14, color=GREEN_3B1B, weight=BOLD)
        winner_text.next_to(winner_crown, UP, buff=0.1)
        self.play(Write(winner_text), run_time=0.5)
        
        self.wait(0.8)
        
        # Step 3: VCG Payment Rule
        step3 = Text("Step 3: VCG Payment Rule", font_size=20, color=RED_3B1B, weight=BOLD)
        step3.next_to(step2, DOWN, buff=0.3, aligned_edge=LEFT)
        
        self.play(Write(step3), run_time=0.8)
        
        # Key insight box
        key_box = RoundedRectangle(
            width=10, height=1.5,
            corner_radius=0.15,
            color=PURPLE_3B1B,
            fill_opacity=0.15,
            stroke_width=3
        )
        key_box.shift(DOWN * 3)
        
        key_text = Text(
            "Winner pays the SECOND-HIGHEST bid\n(the social cost of their participation)",
            font_size=16,
            color=PURPLE_3B1B,
            weight=BOLD
        )
        key_text.move_to(key_box)
        
        self.play(
            Create(key_box),
            Write(key_text),
            run_time=1.2
        )
        self.wait(0.5)
        
        # Show payment calculation
        payment_calc = VGroup(
            Text("Alice's bid:", font_size=14, color=BLUE_3B1B),
            Text("$100", font_size=18, color=BLUE_3B1B, weight=BOLD)
        ).arrange(RIGHT, buff=0.3)
        payment_calc.next_to(key_box, DOWN, buff=0.5).shift(LEFT * 2)
        
        payment_amount = VGroup(
            Text("Alice pays:", font_size=14, color=RED_3B1B),
            Text("$80", font_size=18, color=RED_3B1B, weight=BOLD),
            Text("(Bob's bid)", font_size=12, color=RED_3B1B)
        ).arrange(RIGHT, buff=0.3)
        payment_amount.next_to(payment_calc, RIGHT, buff=1)
        
        self.play(Write(payment_calc), run_time=0.7)
        self.play(
            Write(payment_amount),
            Flash(payment_amount[1], color=RED_3B1B, flash_radius=0.8),
            run_time=1
        )
        
        # Arrow showing payment
        payment_arrow = Arrow(
            start=alice_bidder.get_bottom(),
            end=item_box.get_bottom() + DOWN * 0.5,
            color=RED_3B1B,
            stroke_width=4,
            tip_length=0.3
        )
        
        payment_label = Text("Pays $80", font_size=14, color=RED_3B1B, weight=BOLD)
        payment_label.next_to(payment_arrow, RIGHT, buff=0.2)
        
        self.play(
            GrowArrow(payment_arrow),
            Write(payment_label),
            run_time=0.8
        )
        
        self.wait(1)
        
        # Fade out for next scene
        self.play(
            *[FadeOut(mob) for mob in self.mobjects if mob not in [title]],
            run_time=0.8
        )
        
        self.wait(0.5)