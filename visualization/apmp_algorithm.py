from manim import *

class APMPAlgorithm(Scene):
    def construct(self):
        # 3Blue1Brown colors
        BLUE_3B1B = "#58C4DD"
        YELLOW_3B1B = "#FFFF00"
        GREEN_3B1B = "#4CBF4C"
        RED_3B1B = "#FF6B6B"
        ORANGE_3B1B = "#FFA500"
        PURPLE_3B1B = "#9370DB"
        
        # Title
        title = Text("Auxiliary Proximal Message Passing (APMP) Algorithm", 
                    font_size=32, color=BLUE_3B1B, weight=BOLD)
        title.to_edge(UP)
        self.play(Write(title), run_time=1.2)
        self.wait(0.5)
        
        # Top level: LASCOPF Problem
        lascopf_box = RoundedRectangle(
            width=4, height=1,
            corner_radius=0.2,
            color=RED_3B1B,
            fill_opacity=0.3,
            stroke_width=4
        )
        lascopf_box.shift(UP * 2.5)
        
        lascopf_label = Text("LASCOPF\nProblem", font_size=20, color=RED_3B1B, weight=BOLD)
        lascopf_label.move_to(lascopf_box)
        
        self.play(
            Create(lascopf_box),
            Flash(lascopf_box, color=RED_3B1B, flash_radius=1.2),
            run_time=0.8
        )
        self.play(Write(lascopf_label), run_time=0.7)
        self.wait(0.5)
        
        # Second level: APP Based Coarse-Grained Distribution
        app_box = RoundedRectangle(
            width=6, height=0.9,
            corner_radius=0.15,
            color=PURPLE_3B1B,
            fill_opacity=0.25,
            stroke_width=3
        )
        app_box.shift(UP * 1)
        
        app_label = Text("Auxiliary Problem Principle (APP)\nBased Coarse-Grained Distribution", 
                        font_size=14, color=PURPLE_3B1B, weight=BOLD)
        app_label.move_to(app_box)
        
        # Arrow from LASCOPF to APP
        arrow_to_app = Arrow(
            start=lascopf_box.get_bottom(),
            end=app_box.get_top(),
            color=PURPLE_3B1B,
            stroke_width=3,
            tip_length=0.25
        )
        
        self.play(GrowArrow(arrow_to_app), run_time=0.7)
        self.play(
            Create(app_box),
            Write(app_label),
            run_time=0.9
        )
        self.wait(0.5)
        
        # Third level: Four subproblems (OPF1, OPF2, ED, SCOPF)
        subproblem_y = DOWN * 0.8
        subproblem_spacing = 2.8
        
        subproblems = [
            ("OPF 1", LEFT * 1.5 * subproblem_spacing, BLUE_3B1B),
            ("OPF 2", LEFT * 0.5 * subproblem_spacing, GREEN_3B1B),
            ("ED", RIGHT * 0.5 * subproblem_spacing, ORANGE_3B1B),
            ("SCOPF", RIGHT * 1.5 * subproblem_spacing, YELLOW_3B1B)
        ]
        
        subproblem_boxes = []
        
        for label_text, x_pos, color in subproblems:
            # Main subproblem box
            sub_box = RoundedRectangle(
                width=2.2, height=0.7,
                corner_radius=0.12,
                color=color,
                fill_opacity=0.2,
                stroke_width=3
            )
            sub_box.shift(subproblem_y + x_pos)
            
            sub_label = Text(label_text, font_size=16, color=color, weight=BOLD)
            sub_label.move_to(sub_box)
            
            # Arrow from APP to subproblem
            arrow_to_sub = Arrow(
                start=app_box.get_bottom(),
                end=sub_box.get_top(),
                color=color,
                stroke_width=2.5,
                tip_length=0.2
            )
            
            self.play(GrowArrow(arrow_to_sub), run_time=0.4)
            self.play(
                Create(sub_box),
                Write(sub_label),
                run_time=0.5
            )
            
            subproblem_boxes.append((sub_box, sub_label, color))
        
        self.wait(0.5)
        
        # Fourth level: ADMM based fine-grained distribution for each
        admm_y = DOWN * 2.5
        
        for i, ((sub_box, sub_label, color), (label_text, x_pos, _)) in enumerate(zip(subproblem_boxes, subproblems)):
            # ADMM box
            admm_box = RoundedRectangle(
                width=2.2, height=1.2,
                corner_radius=0.12,
                color=color,
                fill_opacity=0.15,
                stroke_width=2
            )
            admm_box.shift(admm_y + x_pos)
            
            admm_label = Text("ADMM based Proximal\nMessage Passing Fine-\nGrained Distribution", 
                            font_size=9, color=color)
            admm_label.move_to(admm_box)
            
            # Arrow from subproblem to ADMM
            arrow_to_admm = Arrow(
                start=sub_box.get_bottom(),
                end=admm_box.get_top(),
                color=color,
                stroke_width=2,
                tip_length=0.18
            )
            
            self.play(GrowArrow(arrow_to_admm), run_time=0.3)
            self.play(
                Create(admm_box),
                Write(admm_label),
                run_time=0.5
            )
        
        self.wait(0.5)
        
        # Fifth level: Gen, Line, Load decomposition
        component_y = DOWN * 4
        
        for i, ((label_text, x_pos, color_val)) in enumerate(subproblems):
            components = ["Gen", "Line", "Load"]
            component_spacing = 0.6
            
            for j, comp_name in enumerate(components):
                comp_circle = Circle(
                    radius=0.2,
                    color=color_val,
                    fill_opacity=0.3,
                    stroke_width=2
                )
                offset = (j - 1) * component_spacing
                comp_circle.shift(component_y + x_pos + RIGHT * offset)
                
                comp_text = Text(comp_name, font_size=8, color=color_val)
                comp_text.move_to(comp_circle)
                
                self.play(
                    FadeIn(comp_circle, scale=0.5),
                    Write(comp_text),
                    run_time=0.2
                )
        
        self.wait(0.5)
        
        # Bottom: Results/Output
        result_box = RoundedRectangle(
            width=10, height=0.8,
            corner_radius=0.15,
            color=GREEN_3B1B,
            fill_opacity=0.25,
            stroke_width=3
        )
        result_box.shift(DOWN * 5.2)
        
        result_label = Text("Results/Output/Solution", font_size=18, color=GREEN_3B1B, weight=BOLD)
        result_label.move_to(result_box)
        
        # Convergence arrows from all ADMM blocks
        for (label_text, x_pos, color_val) in subproblems:
            arrow_to_result = Arrow(
                start=component_y + x_pos + DOWN * 0.5,
                end=result_box.get_top(),
                color=color_val,
                stroke_width=2,
                tip_length=0.15
            )
            self.play(GrowArrow(arrow_to_result), run_time=0.3)
        
        self.play(
            Create(result_box),
            Flash(result_box, color=GREEN_3B1B, flash_radius=1.5),
            run_time=0.9
        )
        self.play(Write(result_label), run_time=0.7)
        
        self.wait(0.5)
        
        # Add side annotation explaining hierarchy
        annotation = Text(
            "Hierarchical\nDecomposition",
            font_size=14,
            color=BLUE_3B1B,
            weight=BOLD
        )
        annotation.to_corner(UR, buff=0.5)
        
        annotation_box = SurroundingRectangle(
            annotation,
            color=BLUE_3B1B,
            buff=0.15,
            corner_radius=0.1
        )
        
        self.play(
            Create(annotation_box),
            Write(annotation),
            run_time=0.8
        )

        # ZOOM OUT
        all_objects = Group(*self.mobjects)
        self.play(all_objects.animate.scale(0.75).move_to(ORIGIN), run_time=1.5)
        self.wait(0.5)
        
        self.wait(2)