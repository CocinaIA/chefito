from PIL import Image, ImageDraw, ImageFont
import os

def create_chef_mouse_icon():
    # Crear imagen de 1024x1024 (alta resolución para el ícono)
    size = 1024
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Fondo circular naranja
    margin = 50
    draw.ellipse([margin, margin, size-margin, size-margin], 
                 fill='#F97316', outline=None)
    
    # Cuerpo del ratón (gris claro)
    body_color = '#E5E7EB'
    body_x = size // 2
    body_y = size // 2 + 50
    body_radius = 280
    draw.ellipse([body_x - body_radius, body_y - body_radius,
                  body_x + body_radius, body_y + body_radius],
                 fill=body_color, outline='#9CA3AF', width=8)
    
    # Cabeza del ratón
    head_y = size // 2 - 80
    head_radius = 200
    draw.ellipse([body_x - head_radius, head_y - head_radius,
                  body_x + head_radius, head_y + head_radius],
                 fill=body_color, outline='#9CA3AF', width=8)
    
    # Orejas grandes (características de ratón)
    ear_radius = 90
    # Oreja izquierda
    ear_left_x = body_x - 150
    ear_left_y = head_y - 100
    draw.ellipse([ear_left_x - ear_radius, ear_left_y - ear_radius,
                  ear_left_x + ear_radius, ear_left_y + ear_radius],
                 fill='#FFC0CB', outline='#9CA3AF', width=6)
    # Oreja derecha
    ear_right_x = body_x + 150
    ear_right_y = head_y - 100
    draw.ellipse([ear_right_x - ear_radius, ear_right_y - ear_radius,
                  ear_right_x + ear_radius, ear_right_y + ear_radius],
                 fill='#FFC0CB', outline='#9CA3AF', width=6)
    
    # Hocico
    snout_y = head_y + 60
    snout_width = 120
    snout_height = 80
    draw.ellipse([body_x - snout_width//2, snout_y - snout_height//2,
                  body_x + snout_width//2, snout_y + snout_height//2],
                 fill='#F3F4F6', outline='#9CA3AF', width=5)
    
    # Nariz (negra)
    nose_radius = 25
    nose_y = snout_y - 10
    draw.ellipse([body_x - nose_radius, nose_y - nose_radius,
                  body_x + nose_radius, nose_y + nose_radius],
                 fill='#1F2937')
    
    # Ojos
    eye_radius = 18
    eye_y = head_y - 20
    # Ojo izquierdo
    draw.ellipse([body_x - 60 - eye_radius, eye_y - eye_radius,
                  body_x - 60 + eye_radius, eye_y + eye_radius],
                 fill='#1F2937')
    # Ojo derecho
    draw.ellipse([body_x + 60 - eye_radius, eye_y - eye_radius,
                  body_x + 60 + eye_radius, eye_y + eye_radius],
                 fill='#1F2937')
    
    # Gorro de chef (blanco)
    hat_color = '#FFFFFF'
    # Base del gorro
    hat_base_y = head_y - 180
    hat_base_height = 40
    draw.rectangle([body_x - 200, hat_base_y,
                   body_x + 200, hat_base_y + hat_base_height],
                  fill=hat_color, outline='#9CA3AF', width=6)
    
    # Parte superior del gorro (inflada)
    hat_top_y = hat_base_y - 120
    hat_top_radius = 150
    draw.ellipse([body_x - hat_top_radius, hat_top_y - hat_top_radius//2,
                  body_x + hat_top_radius, hat_top_y + hat_top_radius],
                 fill=hat_color, outline='#9CA3AF', width=6)
    
    # Cuchara de cocina (opcional, para dar más contexto de chef)
    spoon_x = body_x + 280
    spoon_y = body_y + 100
    # Mango de la cuchara
    draw.rectangle([spoon_x - 10, spoon_y - 150,
                   spoon_x + 10, spoon_y],
                  fill='#9CA3AF')
    # Cabeza de la cuchara
    draw.ellipse([spoon_x - 40, spoon_y - 200,
                  spoon_x + 40, spoon_y - 120],
                 fill='#D1D5DB', outline='#9CA3AF', width=4)
    
    # Guardar imagen principal
    img.save('app_icon.png', 'PNG')
    print("✓ Ícono principal creado: app_icon.png")
    
    # Crear versión para foreground (sin fondo)
    img_fg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw_fg = ImageDraw.Draw(img_fg)
    
    # Redibujar solo el ratón (sin el círculo naranja de fondo)
    # [Copiar el mismo código del ratón pero sin el fondo circular]
    
    # Cuerpo
    draw_fg.ellipse([body_x - body_radius, body_y - body_radius,
                     body_x + body_radius, body_y + body_radius],
                    fill=body_color, outline='#9CA3AF', width=8)
    # Cabeza
    draw_fg.ellipse([body_x - head_radius, head_y - head_radius,
                     body_x + head_radius, head_y + head_radius],
                    fill=body_color, outline='#9CA3AF', width=8)
    # Orejas
    draw_fg.ellipse([ear_left_x - ear_radius, ear_left_y - ear_radius,
                     ear_left_x + ear_radius, ear_left_y + ear_radius],
                    fill='#FFC0CB', outline='#9CA3AF', width=6)
    draw_fg.ellipse([ear_right_x - ear_radius, ear_right_y - ear_radius,
                     ear_right_x + ear_radius, ear_right_y + ear_radius],
                    fill='#FFC0CB', outline='#9CA3AF', width=6)
    # Hocico
    draw_fg.ellipse([body_x - snout_width//2, snout_y - snout_height//2,
                     body_x + snout_width//2, snout_y + snout_height//2],
                    fill='#F3F4F6', outline='#9CA3AF', width=5)
    # Nariz
    draw_fg.ellipse([body_x - nose_radius, nose_y - nose_radius,
                     body_x + nose_radius, nose_y + nose_radius],
                    fill='#1F2937')
    # Ojos
    draw_fg.ellipse([body_x - 60 - eye_radius, eye_y - eye_radius,
                     body_x - 60 + eye_radius, eye_y + eye_radius],
                    fill='#1F2937')
    draw_fg.ellipse([body_x + 60 - eye_radius, eye_y - eye_radius,
                     body_x + 60 + eye_radius, eye_y + eye_radius],
                    fill='#1F2937')
    # Gorro
    draw_fg.rectangle([body_x - 200, hat_base_y,
                      body_x + 200, hat_base_y + hat_base_height],
                     fill=hat_color, outline='#9CA3AF', width=6)
    draw_fg.ellipse([body_x - hat_top_radius, hat_top_y - hat_top_radius//2,
                     body_x + hat_top_radius, hat_top_y + hat_top_radius],
                    fill=hat_color, outline='#9CA3AF', width=6)
    # Cuchara
    draw_fg.rectangle([spoon_x - 10, spoon_y - 150,
                      spoon_x + 10, spoon_y],
                     fill='#9CA3AF')
    draw_fg.ellipse([spoon_x - 40, spoon_y - 200,
                     spoon_x + 40, spoon_y - 120],
                    fill='#D1D5DB', outline='#9CA3AF', width=4)
    
    img_fg.save('app_icon_foreground.png', 'PNG')
    print("✓ Ícono foreground creado: app_icon_foreground.png")
    print("\n✨ Íconos generados exitosamente!")

if __name__ == '__main__':
    create_chef_mouse_icon()
